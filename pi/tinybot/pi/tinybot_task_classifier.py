import re

TASK_RULES = [
    ('approval', ['approve', 'reject ', 'defer ']),
    ('admin', ['/status', '/health', '/projects', '/help', 'status', 'health check']),
    ('content', ['article', 'blog', 'draft', 'tone', 'revise', 'write about', 'write an article', 'write a blog', 'email draft']),
    ('research', ['research', 'analyze', 'compare', 'find', 'search', 'investigate', 'explain', 'look up', 'what is', 'tell me about']),
    ('dev', ['deploy', 'implement', 'clone', 'commit', 'push', 'debug', 'fix', 'build', 'code', 'create', 'refactor', 'write a', 'add feature']),
]

def classify_task(text):
    t = text.lower()
    for task_type, keywords in TASK_RULES:
        for kw in keywords:
            if kw in t:
                return task_type
    return 'dev'
