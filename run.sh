#!/bin/bash
cd "$(dirname "$0")"
source .venv/bin/activate

SCRIPT_DIR="$(pwd)"
TASK="$1"
MODE="${2:-existing}"

if [ -z "$TASK" ]; then
    TASK="Go to https://creator.douyin.com/creator-micro/content/upload and describe the page"
fi

echo "🚀 启动 Browser Use"
echo "📋 任务: $TASK"
echo "🔧 模式: $MODE"
echo ""

python3 - "$TASK" "$MODE" << 'PYEOF'
import sys
import os
import re
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession
from browser_use.llm.minimax import ChatMiniMax

task = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else 'existing'

load_dotenv(os.path.join('/Users/azm/MyProject/browser-use', '.env'))

api_key = os.getenv('MINIMAX_API_KEY')
if not api_key:
    print('错误: 请在 .env 文件中设置 MINIMAX_API_KEY')
    exit(1)

llm = ChatMiniMax(model='MiniMax-M2.5')

if mode == 'cloud':
    from browser_use import Browser
    browser = Browser(use_cloud=True)
else:
    browser = BrowserSession.from_system_chrome()

file_paths = []
matches = re.findall(r'([/\w\-\.]+\.(?:mp4|mov|avi|mkv|jpg|png|pdf|docx|xlsx))', task, re.IGNORECASE)
for f in matches:
    if os.path.exists(f):
        file_paths.append(f)
        print(f"📎 发现待上传文件: {f}")

agent = Agent(
    task=task,
    llm=llm,
    browser=browser,
    available_file_paths=file_paths if file_paths else None,
)
agent.run_sync()
PYEOF
