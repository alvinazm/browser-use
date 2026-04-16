# 新开浏览器打开
- 无法获取到cookie
bash run_new_chrome.sh "打开https://creator.douyin.com/creator-micro/content/upload 这个页面，然后上传视频，视频地址/Users/azm/Downloads/test.mov " minimax

# 其他模式
./run.sh "你的任务" existing  # 系统 Chrome
./run.sh "打开这个页面：https://creator.douyin.com/creator-micro/content/upload" existing

./run.sh "你的任务" new       # 新浏览器
./run.sh "你的任务" cloud     # Browser Use Cloud