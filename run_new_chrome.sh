#!/bin/bash
# Browser Use 启动脚本
# 使用方法: 
#   ./run.sh "你的任务"              # 使用新浏览器 (默认)
#   ./run.sh "你的任务" existing    # 连接已打开的 Chrome
#   ./run.sh "你的任务" cloud       # 使用 Browser Use Cloud
#   ./run.sh "你的任务" minimax     # 使用 MiniMax

cd "$(dirname "$0")"

# 激活虚拟环境
source .venv/bin/activate

# 解析参数
TASK="${1:-Find the number of stars of the browser-use repo}"
MODE="${2:-new}"

echo "🚀 启动 Browser Use"
echo "📋 任务: $TASK"
echo "🔧 模式: $MODE"
echo ""

# 根据模式选择运行方式
case "$MODE" in
    new)
        # 使用新浏览器（默认）
        python -c "
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession, ChatGoogle

load_dotenv()

browser = BrowserSession()
agent = Agent(
    task=\"$TASK\",
    llm=ChatGoogle(model='gemini-2.5-flash'),
    browser=browser,
)
agent.run_sync()
"
        ;;
    existing)
        # 连接已存在的浏览器
        python -c "
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession, ChatGoogle

load_dotenv()

browser = BrowserSession(cdp_url='http://localhost:9222')
agent = Agent(
    task=\"$TASK\",
    llm=ChatGoogle(model='gemini-2.5-flash'),
    browser=browser,
)
agent.run_sync()
"
        ;;
    cloud)
        # 使用 Browser Use Cloud
        python -c "
from dotenv import load_dotenv
from browser_use import Agent, Browser, ChatGoogle

load_dotenv()

browser = Browser(use_cloud=True)
agent = Agent(
    task=\"$TASK\",
    llm=ChatGoogle(model='gemini-2.5-flash'),
    browser=browser,
)
agent.run_sync()
"
        ;;
minimax)
        # 使用 MiniMax 国内版 - 使用内置的 ChatMiniMax 类
        python -c "
import os
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession
from browser_use.llm.minimax import ChatMiniMax

load_dotenv()

api_key = os.getenv('MINIMAX_API_KEY')
if not api_key:
    print('错误: 请在 .env 文件中设置 MINIMAX_API_KEY')
    exit(1)

# 使用内置的 ChatMiniMax，它正确处理:
# - endpoint: /v1/chat/completions
# - thinking 块: <think>...</think> 过滤
# - reasoning_content: 从 API 响应中提取
llm = ChatMiniMax(
    model='MiniMax-M2.5',
    api_key=api_key,
)

browser = BrowserSession()
agent = Agent(
    task=\"$TASK\",
    llm=llm,
    browser=browser,
)
agent.run_sync()
"
        ;;
    openai)
        # 使用 OpenAI
        python -c "
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession, ChatOpenAI

load_dotenv()

browser = BrowserSession()
agent = Agent(
    task=\"$TASK\",
    llm=ChatOpenAI(model='gpt-4.1-mini'),
    browser=browser,
)
agent.run_sync()
"
        ;;
    anthropic)
        # 使用 Anthropic Claude
        python -c "
from dotenv import load_dotenv
from browser_use import Agent, BrowserSession, ChatAnthropic

load_dotenv()

browser = BrowserSession()
agent = Agent(
    task=\"$TASK\",
    llm=ChatAnthropic(model='claude-sonnet-4-20250514'),
    browser=browser,
)
agent.run_sync()
"
        ;;
    *)
        echo "不支持的模式: $MODE"
        echo "支持的选项: new, existing, cloud, minimax, openai, anthropic"
        exit 1
        ;;
esac