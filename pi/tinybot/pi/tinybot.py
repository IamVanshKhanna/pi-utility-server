import os
import sys
import logging
import asyncio
import subprocess
import urllib.request
import urllib.parse
import re

from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

TINYBOT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(TINYBOT_ROOT, ".env")


def load_env(path):
    data = {}
    if not os.path.exists(path):
        return data
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                data[key.strip()] = val.strip().strip('"').strip("'")
    return data


_env = load_env(ENV_PATH)
BOT_TOKEN = _env.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
ADMIN_CHAT_IDS = set()
raw_ids = _env.get("ADMIN_CHAT_IDS") or os.environ.get("ADMIN_CHAT_IDS", "")
for cid in raw_ids.split(","):
    cid = cid.strip()
    if cid:
        ADMIN_CHAT_IDS.add(int(cid))


def admin_only(func):
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if not ADMIN_CHAT_IDS:
            await update.message.reply_text("Bot misconfigured: no ADMIN_CHAT_IDS set.")
            return
        if update.message.chat_id not in ADMIN_CHAT_IDS:
            logger.warning(f"Unauthorized access from chat_id={update.message.chat_id}")
            await update.message.reply_text("Unauthorized.")
            return
        return await func(update, context)
    wrapper.__name__ = func.__name__
    return wrapper


def search_web(query, max_results=4):
    try:
        data = urllib.parse.urlencode({"q": query}).encode()
        req = urllib.request.Request(
            "https://lite.duckduckgo.com/lite/",
            data=data,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode("utf-8", errors="replace")

        links = re.findall(r"<a\s+([^>]+)>(.*?)</a>", html, re.DOTALL)
        snippets = re.findall(r"class='result-snippet'>(.*?)</td>", html, re.DOTALL)

        results = []
        si = 0
        for attrs, txt in links:
            if "result-link" in attrs:
                href_m = re.search(r'href="([^"]*)"', attrs)
                href = href_m.group(1) if href_m else ""
                title = re.sub(r"<[^>]+>", "", txt).strip()
                body = re.sub(r"<[^>]+>", "", snippets[si]).strip() if si < len(snippets) else ""
                si += 1
                results.append(f"\u2022 {title}\n  {body}\n  {href}")

        if not results:
            return "No results found."
        return "\n\n".join(results[:max_results])
    except Exception as e:
        logger.warning(f"Search failed: {e}")
        return None


@admin_only
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "Hey! I'm TinyBot on a Raspberry Pi 4B.\n"
        "Commands: /health, /fan, /search, /chatid, /help"
    )


@admin_only
async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "/help          - This message\n"
        "/health        - Pi CPU, RAM, temp, disk\n"
        "/fan           - Show fan status\n"
        "/fan 0-100     - Set fan speed (0=off)\n"
        "/fan auto      - Auto (PWM DeskPi service)\n"
        "/docker        - List active containers\n"
        "/docker close  - Stop a container\n"
        "/docker restart- Restart a container\n"
        "/search        - Web search (DuckDuckGo)\n"
        "/chatid        - Your Telegram chat ID\n"
        "/start         - Greeting"
    )


@admin_only
async def fan_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    args = " ".join(context.args).strip()

    FAN_STATE = "/tmp/fan_speed_val"

    if args == "auto":
        subprocess.run(["sudo", "systemctl", "start", "deskpi.service"], capture_output=True, timeout=15)
        try:
            os.remove(FAN_STATE)
        except Exception:
            pass
        await update.message.reply_text("Fan set to PWM auto (DeskPi service)")
        return

    if args in ("100", "75", "50", "25", "0"):
        speed = args
        speeds = {"100": "pwm_100", "75": "pwm_075", "50": "pwm_050", "25": "pwm_025", "0": "pwm_000"}
        subprocess.run(["sudo", "systemctl", "stop", "deskpi.service"], capture_output=True, timeout=15)
        subprocess.run(["sudo", "tee", "/dev/ttyUSB0"], input=(speeds[speed] + "\n").encode(), capture_output=True, timeout=10)
        with open(FAN_STATE, "w") as f:
            f.write(speed)
        await update.message.reply_text(f"Fan set to {speed}%")
        return
    elif args:
        await update.message.reply_text("Usage: /fan [0|25|50|75|100|auto]\n  No arg = show status")
        return

    temp = "N/A"
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            val = int(f.read().strip())
            temp = f"{val / 1000:.1f}C"
    except Exception:
        pass
    gpio_result = subprocess.run(["pinctrl", "12"], capture_output=True, text=True, timeout=10)
    raw = gpio_result.stdout.strip()
    if "hi" in raw:
        gpio = "HIGH"
    elif "lo" in raw:
        gpio = "LOW"
    else:
        gpio = raw or "N/A"
    deskpi_result = subprocess.run(["systemctl", "is-active", "deskpi.service"], capture_output=True, text=True, timeout=10)
    deskpi = deskpi_result.stdout.strip()
    with open("/proc/loadavg") as f:
        load = f.read().split()[:3]
    if deskpi == "active":
        fan_status = "AUTO (DeskPi PWM)"
    else:
        try:
            with open(FAN_STATE) as f:
                manual = f.read().strip()
            fan_status = f"MANUAL {manual}%"
        except Exception:
            fan_status = "MANUAL (unknown %)"
    await update.message.reply_text(
        f"Fan Status:\n"
        f"Temp:      {temp}\n"
        f"GPIO12:    {gpio}\n"
        f"Fan:       {fan_status}\n"
        f"Load 1m:   {load[0]}\n"
        f"Load 5m:   {load[1]}\n"
        f"Load 15m:  {load[2]}"
    )


@admin_only
async def health_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    import psutil
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            temp = int(f.read().strip()) / 1000
    except Exception:
        temp = None

    uptime_result = subprocess.run(["uptime", "-p"], capture_output=True, text=True, timeout=10)
    uptime_str = uptime_result.stdout.strip() or "N/A"

    msg = (
        f"CPU: {cpu}%\n"
        f"RAM: {mem.percent}% ({mem.used // 1024 // 1024}MB / {mem.total // 1024 // 1024}MB)\n"
        f"Disk: {disk.percent}% ({disk.free // 1024 // 1024 // 1024}GB free)\n"
    )
    if temp is not None:
        msg += f"Temp: {temp:.1f}C\n"
    msg += f"Uptime: {uptime_str}"
    await update.message.reply_text(msg.strip())


async def search_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = " ".join(context.args)
    if not query:
        await update.message.reply_text("Usage: /search <query>")
        return

    await update.message.reply_text("Searching the web...")
    loop = asyncio.get_event_loop()
    search_results = await loop.run_in_executor(None, search_web, query)

    if search_results is None:
        await update.message.reply_text("Search failed. The Pi may not have internet, or DuckDuckGo is rate-limiting.")
        return
    if search_results == "No results found.":
        await update.message.reply_text("No results found for that query.")
        return

    await update.message.reply_text(f'Web search results for "{query}":\n\n{search_results}')


async def chatid_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    cid = update.message.chat_id
    await update.message.reply_text(f"Your chat ID: {cid}")


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "I'm a simple bot - no LLM running on this Pi.\n"
        "Use /search <query> for web search, or /health for system status."
    )


@admin_only
async def docker_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    args = " ".join(context.args).strip().split(None, 1)
    action = args[0].lower() if args else "list"
    logger.info(f"/docker called with action={action} args={args}")

    if action == "close" and len(args) > 1:
        name = args[1]
        ps_result = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=30)
        running = ps_result.stdout.strip().splitlines()
        if name not in running:
            await update.message.reply_text(f"Container '{name}' not found in running containers.")
            return
        result = subprocess.run(["docker", "stop", name], capture_output=True, text=True, timeout=60)
        out = result.stdout.strip() or result.stderr.strip()
        logger.info(f"Stop result: {out[:100]}")
        await update.message.reply_text(f"Stopped: {name}" if len(out) < 200 else f"Stopped: {name}")
        return

    if action == "restart" and len(args) > 1:
        name = args[1]
        ps_result = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=30)
        running = ps_result.stdout.strip().splitlines()
        if name not in running:
            await update.message.reply_text(f"Container '{name}' not found in running containers.")
            return
        result = subprocess.run(["docker", "restart", name], capture_output=True, text=True, timeout=60)
        out = result.stdout.strip() or result.stderr.strip()
        logger.info(f"Restart result: {out[:100]}")
        await update.message.reply_text(f"Restarted: {name}" if len(out) < 200 else f"Restarted: {name}")
        return

    if action not in ("list", "close", "restart"):
        await update.message.reply_text("Usage:\n/docker              - list all containers\n/docker close <name> - stop a container\n/docker restart <name> - restart a container")
        return

    logger.info("Listing containers")
    ps_result = subprocess.run(
        ["docker", "ps", "--format", "{{.Names}}|{{.Status}}|{{.Ports}}"],
        capture_output=True, text=True, timeout=30
    )
    raw = ps_result.stdout
    logger.info(f"Raw output length: {len(raw)}")
    if not raw or raw.startswith("Cannot") or "error" in raw.lower():
        logger.warning(f"Docker list failed: {raw[:200]}")
        await update.message.reply_text("No containers running or Docker error.")
        return

    lines = raw.strip().split("\n")
    out = f"Active Containers ({len(lines)})\n"
    out += "=" * 24 + "\n"
    for idx, l in enumerate(lines, 1):
        parts = l.strip().split("|", 2)
        name = parts[0] if parts else "?"
        raw_ports = parts[2].strip() if len(parts) > 2 and parts[2].strip() else "-"
        if raw_ports != "-":
            seen = set()
            short = []
            for p in raw_ports.split(", "):
                port = p.split("->")[0].rsplit(":", 1)[-1]
                if port not in seen:
                    short.append(port)
                    seen.add(port)
            line = f"{idx}. {name} ({', '.join(short)})" if short else f"{idx}. {name}"
        else:
            line = f"{idx}. {name}"
        out += "\n" + line
    logger.info(f"Response length: {len(out)}")
    await update.message.reply_text(out.strip())


def main():
    if not BOT_TOKEN:
        logger.error("TELEGRAM_BOT_TOKEN not set.")
        sys.exit(1)
    if not ADMIN_CHAT_IDS:
        logger.error("ADMIN_CHAT_IDS not set. Add comma-separated chat IDs to .env")
        sys.exit(1)

    import telegram
    app = ApplicationBuilder().token(BOT_TOKEN).post_init(register_commands).connect_timeout(30).read_timeout(30).write_timeout(30).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("health", health_command))
    app.add_handler(CommandHandler("fan", fan_command))
    app.add_handler(CommandHandler("search", search_command))
    app.add_handler(CommandHandler("chatid", chatid_command))
    app.add_handler(CommandHandler("docker", docker_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    logger.info("TinyBot starting (no LLM)...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


async def register_commands(app):
    cmds = [
        ("help", "Show commands"),
        ("health", "Pi system status"),
        ("fan", "Show/set fan speed (0-100)"),
        ("docker", "List/manage containers"),
        ("search", "Search the web"),
        ("chatid", "Your Telegram chat ID"),
        ("start", "Greeting"),
    ]
    try:
        await app.bot.set_my_commands([telegram.BotCommand(c, d) for c, d in cmds])
        logger.info("Registered bot commands with Telegram")
    except Exception as e:
        logger.warning(f"Could not register commands: {e}")


if __name__ == "__main__":
    main()

