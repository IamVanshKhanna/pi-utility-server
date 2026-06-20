#!/usr/bin/env python3
"""
Cache Warming Strategies for Homelab Services
Pre-populates caches to improve response times after deployments/restarts.
"""

import os
import sys
import time
import requests
import redis
import psycopg2
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
class Config:
    # Redis
    REDIS_HOST = os.environ.get("REDIS_HOST", "homelab-redis.databases.svc.cluster.local")
    REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
    REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD")
    
    # PostgreSQL
    PGHOST = os.environ.get("PGHOST", "homelab-postgres.databases.svc.cluster.local")
    PGPORT = int(os.environ.get("PGPORT", "5432"))
    PGDATABASE = os.environ.get("PGDATABASE", "homelab_db")
    PGUSER = os.environ.get("PGUSER", "admin")
    PGPASSWORD = os.environ.get("PGPASSWORD")
    
    # Services
    NEXTCLOUD_URL = os.environ.get("NEXTCLOUD_URL", "https://nextcloud.homelab.local")
    VAULTWARDEN_URL = os.environ.get("VAULTWARDEN_URL", "https://vaultwarden.homelab.local")
    GRAFANA_URL = os.environ.get("GRAFANA_URL", "https://grafana.homelab.local")
    
    # Auth
    NEXTCLOUD_USER = os.environ.get("NEXTCLOUD_USER")
    NEXTCLOUD_PASS = os.environ.get("NEXTCLOUD_PASS")
    VAULTWARDEN_TOKEN = os.environ.get("VAULTWARDEN_TOKEN")
    GRAFANA_API_KEY = os.environ.get("GRAFANA_API_KEY")

# ============================
# Redis Cache Warming
# ============================

def warm_redis_cache() -> Dict[str, Any]:
    """Warm Redis cache with frequently accessed keys"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    try:
        r = redis.Redis(
            host=Config.REDIS_HOST,
            port=Config.REDIS_PORT,
            password=Config.REDIS_PASSWORD,
            decode_responses=True,
            socket_timeout=5,
            socket_connect_timeout=5
        )
        r.ping()
        
        # Frequently accessed keys to pre-populate
        warm_keys = {
            # Session data
            "session:active_users": {"type": "set", "value": []},
            "session:recent_logins": {"type": "list", "value": []},
            
            # Feature flags
            "feature:maintenance_mode": {"type": "string", "value": "false"},
            "feature:registration_open": {"type": "string", "value": "true"},
            
            # Rate limit counters (pre-initialize)
            "ratelimit:global": {"type": "string", "value": "0"},
            "ratelimit:login": {"type": "string", "value": "0"},
            "ratelimit:api": {"type": "string", "value": "0"},
            
            # Cache configuration
            "config:cache_ttl_default": {"type": "string", "value": "3600"},
            "config:cache_ttl_long": {"type": "string", "value": "86400"},
            "config:cache_ttl_short": {"type": "string", "value": "300"},
        }
        
        pipe = r.pipeline()
        for key, config in warm_keys.items():
            if config["type"] == "string":
                if not r.exists(key):
                    pipe.set(key, config["value"])
                    results["warmed"] += 1
            elif config["type"] == "set":
                if not r.exists(key):
                    pipe.sadd(key, *config["value"])
                    results["warmed"] += 1
            elif config["type"] == "list":
                if not r.exists(key):
                    pipe.rpush(key, *config["value"])
                    results["warmed"] += 1
        
        pipe.execute()
        logger.info(f"Redis cache warmed: {results['warmed']} keys")
        
    except Exception as e:
        results["errors"] += 1
        results["details"].append(f"Redis error: {e}")
        logger.error(f"Redis cache warming failed: {e}")
    
    return results

# ============================
# PostgreSQL Cache Warming
# ============================

def warm_postgresql_cache() -> Dict[str, Any]:
    """Warm PostgreSQL buffer cache with frequently accessed tables"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    try:
        conn = psycopg2.connect(
            host=Config.PGHOST,
            port=Config.PGPORT,
            database=Config.PGDATABASE,
            user=Config.PGUSER,
            password=Config.PGPASSWORD,
            connect_timeout=10
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        # Tables to pre-load into shared_buffers
        warm_tables = [
            # Nextcloud
            "oc_filecache",
            "oc_accounts",
            "oc_share",
            "oc_properties",
            "oc_storages",
            
            # Vaultwarden
            "vault",
            "secret",
            "organization",
            "user",
            
            # Authelia
            "user",
            "session",
            
            # System
            "pg_stat_statements",
        ]
        
        for table in warm_tables:
            try:
                # Check if table exists
                cur.execute("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = %s
                    )
                """, (table,))
                
                if cur.fetchone()[0]:
                    # Sequential scan to load into shared_buffers
                    cur.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cur.fetchone()[0]
                    logger.info(f"Warmed table {table}: {count} rows")
                    results["warmed"] += 1
                    
            except Exception as e:
                logger.warning(f"Could not warm table {table}: {e}")
        
        # Warm indexes by running common queries
        warm_queries = [
            "SELECT * FROM oc_filecache WHERE storage = 1 LIMIT 1000",
            "SELECT * FROM oc_share WHERE share_type = 0 LIMIT 1000",
            "SELECT * FROM vault WHERE user_id = 1 LIMIT 100",
        ]
        
        for query in warm_queries:
            try:
                cur.execute(query)
                cur.fetchall()
                results["warmed"] += 1
            except:
                pass
        
        logger.info(f"PostgreSQL cache warmed: {results['warmed']} operations")
        
    except Exception as e:
        results["errors"] += 1
        results["details"].append(f"PostgreSQL error: {e}")
        logger.error(f"PostgreSQL cache warming failed: {e}")
    finally:
        if 'conn' in locals():
            conn.close()
    
    return results

# ============================
# HTTP Service Cache Warming
# ============================

def warm_nextcloud() -> Dict[str, Any]:
    """Warm Nextcloud caches (apps, configs, file listing)"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    if not Config.NEXTCLOUD_USER or not Config.NEXTCLOUD_PASS:
        results["details"].append("Nextcloud credentials not configured")
        return results
    
    try:
        session = requests.Session()
        session.auth = (Config.NEXTCLOUD_USER, Config.NEXTCLOUD_PASS)
        session.headers.update({
            "Accept-Encoding": "br, gzip, deflate",
            "User-Agent": "CacheWarmer/1.0"
        })
        base = Config.NEXTCLOUD_URL
        
        # Endpoints to warm
        endpoints = [
            "/status.php",                    # Health check
            "/index.php/apps/files/",         # Files app
            "/ocs/v2.php/apps/files/",        # Files API
            "/remote.php/dav/files/",         # WebDAV
            "/index.php/core/preview.png",    # Preview generation
            "/index.php/apps/photos/",        # Photos app
        ]
        
        for endpoint in endpoints:
            try:
                response = session.get(f"{base}{endpoint}", timeout=30)
                if response.status_code < 400:
                    results["warmed"] += 1
                    logger.info(f"Warmed Nextcloud: {endpoint}")
                else:
                    results["errors"] += 1
            except Exception as e:
                results["errors"] += 1
                logger.warning(f"Nextcloud {endpoint}: {e}")
        
        logger.info(f"Nextcloud cache warmed: {results['warmed']} endpoints")
        
    except Exception as e:
        results["errors"] += 1
        results["details"].append(f"Nextcloud error: {e}")
        logger.error(f"Nextcloud cache warming failed: {e}")
    
    return results

def warm_vaultwarden() -> Dict[str, Any]:
    """Warm Vaultwarden caches"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    try:
        session = requests.Session()
        session.headers.update({
            "Accept-Encoding": "br, gzip, deflate",
            "User-Agent": "CacheWarmer/1.0"
        })
        if Config.VAULTWARDEN_TOKEN:
            session.headers["Authorization"] = f"Bearer {Config.VAULTWARDEN_TOKEN}"
        
        base = Config.VAULTWARDEN_URL
        endpoints = [
            "/alive",                    # Health
            "/api/sync",                 # Sync endpoint
            "/identity/connect/token",   # Token endpoint
        ]
        
        for endpoint in endpoints:
            try:
                response = session.get(f"{base}{endpoint}", timeout=15)
                if response.status_code < 400:
                    results["warmed"] += 1
            except:
                results["errors"] += 1
        
    except Exception as e:
        results["errors"] += 1
        results["details"].append(f"Vaultwarden error: {e}")
    
    return results

def warm_grafana() -> Dict[str, Any]:
    """Warm Grafana dashboard caches"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    if not Config.GRAFANA_API_KEY:
        return results
    
    try:
        session = requests.Session()
        session.headers.update({
            "Authorization": f"Bearer {Config.GRAFANA_API_KEY}",
            "Accept-Encoding": "br, gzip, deflate",
            "User-Agent": "CacheWarmer/1.0"
        })
        base = Config.GRAFANA_URL
        
        # Get dashboards
        response = session.get(f"{base}/api/search", timeout=15)
        if response.status_code == 200:
            dashboards = response.json()
            
            # Warm top 10 dashboards
            for dash in dashboards[:10]:
                try:
                    uid = dash.get("uid")
                    if uid:
                        session.get(f"{base}/api/dashboards/uid/{uid}", timeout=10)
                        results["warmed"] += 1
                except:
                    results["errors"] += 1
        
    except Exception as e:
        results["errors"] += 1
        results["details"].append(f"Grafana error: {e}")
    
    return results

# ============================
# CDN/Edge Cache Warming
# ============================

def warm_cloudflare_cache() -> Dict[str, Any]:
    """Trigger Cloudflare cache purge and pre-load for critical paths"""
    results = {"warmed": 0, "errors": 0, "details": []}
    
    # This would use Cloudflare API to purge and pre-load
    # Implementation depends on Cloudflare Workers/Pages setup
    logger.info("Cloudflare cache warming placeholder - implement via API")
    results["details"].append("Cloudflare cache warming requires API integration")
    
    return results

# ============================
# Main Orchestration
# ============================

def run_all_warming(parallel: bool = True) -> Dict[str, Any]:
    """Run all cache warming strategies"""
    start_time = time.time()
    
    warming_functions = [
        ("redis", warm_redis_cache),
        ("postgresql", warm_postgresql_cache),
        ("nextcloud", warm_nextcloud),
        ("vaultwarden", warm_vaultwarden),
        ("grafana", warm_grafana),
        ("cloudflare", warm_cloudflare_cache),
    ]
    
    total_results = {
        "start_time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "services": {},
        "summary": {"total_warmed": 0, "total_errors": 0}
    }
    
    if parallel:
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {executor.submit(fn): name for name, fn in warming_functions}
            
            for future in as_completed(futures):
                name = futures[future]
                try:
                    result = future.result()
                    total_results["services"][name] = result
                    total_results["summary"]["total_warmed"] += result.get("warmed", 0)
                    total_results["summary"]["total_errors"] += result.get("errors", 0)
                except Exception as e:
                    total_results["services"][name] = {"warmed": 0, "errors": 1, "details": [str(e)]}
                    total_results["summary"]["total_errors"] += 1
    else:
        for name, fn in warming_functions:
            logger.info(f"Running cache warming for {name}...")
            result = fn()
            total_results["services"][name] = result
            total_results["summary"]["total_warmed"] += result.get("warmed", 0)
            total_results["summary"]["total_errors"] += result.get("errors", 0)
    
    total_results["duration_seconds"] = round(time.time() - start_time, 2)
    total_results["end_time"] = time.strftime("%Y-%m-%d %H:%M:%S")
    
    logger.info(f"Cache warming completed in {total_results['duration_seconds']}s")
    logger.info(f"Total warmed: {total_results['summary']['total_warmed']}, Errors: {total_results['summary']['total_errors']}")
    
    return total_results

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Cache Warming for Homelab Services")
    parser.add_argument("--service", choices=[f[0] for f in warming_functions] + ["all"], default="all")
    parser.add_argument("--parallel", action="store_true", default=True)
    parser.add_argument("--sequential", action="store_false", dest="parallel")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    
    if args.service == "all":
        result = run_all_warming(parallel=args.parallel)
    else:
        fn = next(f[1] for f in warming_functions if f[0] == args.service)
        result = {args.service: fn()}
        result["summary"] = {"total_warmed": result[args.service].get("warmed", 0), 
                            "total_errors": result[args.service].get("errors", 0)}
    
    if args.json:
        import json
        print(json.dumps(result, indent=2))
    else:
        print(f"\nCache Warming Summary:")
        print(f"  Duration: {result.get('duration_seconds', 'N/A')}s")
        print(f"  Total Warmed: {result['summary']['total_warmed']}")
        print(f"  Total Errors: {result['summary']['total_errors']}")
        for svc, res in result.get("services", {}).items():
            print(f"  {svc}: {res.get('warmed', 0)} warmed, {res.get('errors', 0)} errors")
    
    # Exit with error if any failures
    if result["summary"]["total_errors"] > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()