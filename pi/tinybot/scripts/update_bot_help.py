#!/usr/bin/env python3
"""Rewrite help_command and add setMyCommands to the Hermes bot."""
path = "/home/vansh/raspi-devops-homelab/tinybot/pi/telegram_bot.py"
with open(path) as f:
    lines = f.readlines()

# Replace help_command text
new_help = '''async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
        "🤖 HERMES — COMMANDS\\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n\\n"
        "📋 PROJECTS\\n"
        "/new <name> <desc>  — Create new project\\n"
        "/switch <id>        — Switch active project\\n"
        "/projects           — List all projects\\n"
        "/status             — System + queue status\\n\\n"
        "🛡️ APPROVALS\\n"
        "/approve <id>       — Approve pending action\\n"
        "/reject <id> [why]  — Reject pending action\\n"
        "/defer <id> <dur>   — Defer (2h, tomorrow 9am)\\n\\n"
        "🔧 SYSTEM\\n"
        "/health             — Pi health (temp, disk, mem)\\n"
        "/help               — This message\\n\\n"
        "💬 Just send any message to create a task."
    )


'''
lines[87:100] = []  # Remove old help function
lines.insert(87, new_help)

# Add async command registration + use post_init
handler_idx = next(i for i, l in enumerate(lines) if 'app.add_handler(CommandHandler("start"' in l)
set_commands = '''import telegram

async def register_commands(app):
    cmds = [
        ("new", "Create a new project"),
        ("switch", "Switch active project"),
        ("projects", "List all projects"),
        ("status", "System + queue status"),
        ("health", "Pi health report"),
        ("approve", "Approve pending action"),
        ("reject", "Reject pending action"),
        ("defer", "Defer approval"),
        ("help", "Show all commands"),
    ]
    try:
        await app.bot.set_my_commands([telegram.BotCommand(c, d) for c, d in cmds])
        logger.info("Registered bot commands with Telegram")
    except Exception as e:
        logger.warning(f"Could not register commands: {e}")


'''
lines.insert(handler_idx, set_commands)

# Change ApplicationBuilder to use post_init
builder_line = next(i for i, l in enumerate(lines) if 'ApplicationBuilder().token(' in l)
lines[builder_line] = '    app = ApplicationBuilder().token(BOT_TOKEN).post_init(register_commands).build()\n'

with open(path, 'w') as f:
    f.writelines(lines)
print("Done")
