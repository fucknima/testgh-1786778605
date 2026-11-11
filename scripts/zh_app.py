#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""简体中文本地化：修改编译工作区，不修改模型 ID、API、变量名和数据格式。"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

APP = {
    "Sources/StupidAgent/ConversationsView.swift": {
        "Set Up a Model": "配置模型",
        "Bring your own model: an API key from OpenAI, OpenRouter or another OpenAI-compatible server, or a model running on your computer.": "请先配置模型：可使用 OpenAI、OpenRouter 等兼容服务，或电脑上运行的本地模型。",
        "Delete": "删除",
        "Search": "搜索",
        "No Chats": "暂无对话",
        "Start a chat to ask the agent to work with your files.": "创建新对话，让智能体帮你处理文件。",
        "Chats": "对话",
        "Chat Not Found": "找不到对话",
        "Settings": "设置",
        r"Delete \u{201C}\(pendingDelete?.title ?? "")\u{201D}?": r"确定删除“\(pendingDelete?.title ?? "")”吗？",
        "Cancel": "取消",
        "Delete Chat": "删除对话",
        "This deletes the conversation. Files the agent made stay in your workspace.": "删除后无法恢复聊天记录；智能体创建的文件会保留在工作区。",
        "New Chat": "新建对话",
        "No messages yet": "暂无消息",
        "Yesterday": "昨天",
    },
    "Sources/StupidAgent/SettingsView.swift": {
        "Provider": "服务提供商",
        "Custom": "自定义",
        "Base URL": "接口地址",
        "API Key": "API 密钥",
        "API Key (optional)": "API 密钥（选填）",
        "Server": "服务器",
        "On a phone, replace localhost with your computer's address on the local network.": "在手机上连接本地模型时，请把 localhost 替换为电脑的局域网 IP 地址。",
        "Enter your OpenCode Go subscription key. Every conversation gets a stable session ID, including its title requests.": "请输入 OpenCode Go 订阅密钥。每个对话（含标题生成）均使用固定的会话 ID。",
        "Any server that speaks the OpenAI Chat Completions API. The key is stored in the Keychain on this device.": "支持兼容 OpenAI Chat Completions 接口的服务。API 密钥仅存储在本机钥匙串中。",
        "Model ID": "模型 ID",
        "Available Models": "可用模型",
        "Loading Models…": "正在加载模型…",
        "Load Models": "加载模型",
        "Reasoning Model": "推理模型",
        "Thinking": "思考强度",
        "Accepts Images": "支持图片",
        "Model": "模型",
        "Ask Before Changing Files": "修改文件前确认",
        "Access Other Apps": "访问其他 App 文件",
        "Workspace": "工作区",
        "The agent works in this app's folder, which you can open in the Files app under On My iPhone → stupid agent.": "智能体使用本 App 文件夹作为工作区。可在“文件”→“我的 iPhone”→ stupid agent 中查看。",
        "The agent can also read and write files in other apps' containers. Requires iOS 26 or later on a real device.": "开启后可以读取和修改其他 App 的容器文件。需要运行 iOS 26 或更新系统的真机。",
        "Web Search": "网页搜索",
        "Tools": "工具",
        "The agent can search the web, read pages and run JavaScript. Searches go to the provider chosen here; neither needs an API key.": "智能体可搜索网页、读取网页及执行 JavaScript。搜索使用所选服务，无需额外密钥。",
        "Settings": "设置",
        "Cancel": "取消",
        "Save": "保存",
        "Not available on this device.": "当前设备不支持此功能。",
        r"\(found) apps found": r"已发现 \(found) 个 App",
        "Checking for recently-installed apps…": "正在检查最近安装的 App…",
        "Starting…": "正在启动…",
        r"Last indexed \(lastIndexed.formatted(date: .abbreviated, time: .shortened))": r"上次索引：\(lastIndexed.formatted(date: .abbreviated, time: .shortened))",
        "Not indexed yet.": "尚未建立索引。",
        "Reindex Apps": "重新索引 App",
        "App Index": "App 索引",
        "The agent finds other apps by scanning once in the background; this can take a few minutes the first time. Later launches are instant and pick up newly installed apps automatically.": "首次扫描其他 App 可能需要几分钟；以后启动时会使用缓存，并自动发现新安装的 App。",
        "The server listed no models.": "服务器未返回可用模型。",
        r"Couldn't save: \(error.localizedDescription)": r"保存失败：\(error.localizedDescription)",
    },
    "Sources/StupidAgent/ModelPickerView.swift": {
        r"Use \u{201C}\(trimmedQuery)\u{201D}": r"使用“\(trimmedQuery)”",
        "No Models": "暂无模型",
        "The server listed no models. Type a model ID to use it.": "服务器未返回模型列表，可手动输入模型 ID。",
        "Search or Type a Model ID": "搜索或输入模型 ID",
        "Model": "模型",
        "Cancel": "取消",
        r"Couldn't load the server's models: \(error.localizedDescription)": r"获取模型列表失败：\(error.localizedDescription)",
        r"Couldn't switch models: \(error.localizedDescription)": r"切换模型失败：\(error.localizedDescription)",
    },
    "Sources/StupidAgent/AgentChatAdapter.swift": {
        "stupid agent": "智能体",
        "You": "我",
        "Retry": "重试",
        "Choose Model…": "选择模型…",
        "Model": "模型",
        r"Couldn't switch models: \(error.localizedDescription)": r"切换模型失败：\(error.localizedDescription)",
        "Thinking…": "正在思考…",
        "Thought": "思考过程",
        r"\(call.title) · Failed": r"\(call.title) · 失败",
        r"\(call.title) · Stopped": r"\(call.title) · 已停止",
        "Preparing…": "正在准备…",
        "Running…": "正在执行…",
        "The run ended before this finished.": "任务完成前已停止。",
        "No output": "无输出",
    },
    "Sources/StupidAgent/AgentChatView.swift": {
        "Don't Allow": "不允许",
        "Allow": "允许",
        "Couldn't Send": "发送失败",
        "OK": "确定",
    },
    "Sources/StupidAgentCore/AgentSession.swift": {
        r"Edit \(path)?": r"确定编辑 \(path)？",
        r"Overwrite \(path)?": r"确定覆盖 \(path)？",
        r"Create \(path)?": r"确定创建 \(path)？",
        "your workspace": "你的工作区",
        "another app's container": "其他 App 的容器",
        r"The agent wants to change this file in \(place).": r"智能体想要修改\(place)中的此文件。",
        r"The agent wants to replace this file's contents in \(place).": r"智能体想要覆盖\(place)中的此文件。",
        r"The agent wants to create this file in \(place).": r"智能体想要在\(place)中新建文件。",
        r"Couldn't save the conversation: \(error.localizedDescription)": r"保存对话失败：\(error.localizedDescription)",
        r"The user declined this change to \(path).": r"用户拒绝修改 \(path)。",
        "Operation aborted": "操作已取消",
    },
    "Sources/StupidAgentCore/ChatEntries.swift": {
        "Read": "读取",
        "Write": "写入",
        "Edit": "编辑",
        "List": "列出",
        "Find": "查找",
        "Search": "搜索",
        "Search the web for": "网页搜索",
        "Fetch": "获取网页",
        "Run JavaScript": "运行 JavaScript",
        "The response failed.": "模型响应失败。",
        "Stopped": "已停止",
        " in ": "（位置：",
    },
    "Sources/StupidAgentCore/ModelSettings.swift": {
        "Custom": "自定义",
        r"The server answered \(status) when listing models.": r"获取模型列表时，服务器返回状态码 \(status)。",
    },
    "Sources/StupidAgent/SandboxBridge.swift": {
        "The app group container is unavailable. Check the App Groups entitlement and signing.": "App Group 容器不可用，请检查 App Groups 权限及签名。",
        "Couldn't load the container manager library.": "无法加载容器管理库。",
        r"Couldn't resolve the private symbol \(name). This iOS version may not be supported.": r"无法解析系统符号 \(name)，当前 iOS 版本可能不受支持。",
        r"Nothing exists at \(path). Turn off the existence check for a parent directory.": r"路径 \(path) 不存在。要访问父目录，请关闭存在性检查。",
        r"Couldn't replace the app group's Caches directory with a symlink to \(path).": r"无法将 App Group 缓存目录链接到 \(path)。",
        "Couldn't create a container query.": "无法创建容器查询。",
        r"The container query for \(path) was rejected.": r"针对 \(path) 的容器查询被拒绝。",
        "The container manager issued no sandbox token.": "容器管理器未返回沙盒令牌。",
        r"Consuming the sandbox extension failed (\(code)).": r"加载沙盒扩展失败（\(code)）。",
    },
    "Sources/StupidAgentCore/AppContainers.swift": {
        "List apps": "列出 App",
        r"Still indexing other apps (\(percent)% done); \(list.count) found so far. Call apps again later for the rest.": r"正在索引其他 App（已完成 \(percent)%），目前找到 \(list.count) 个。稍后可再次使用 apps 工具查看其余结果。",
        r"Apps:\n": r"App 列表：\n",
        r"App groups:\n": r"App 群组：\n",
        "No other app containers are visible.": "没有发现可访问的其他 App 容器。",
        "app group": "App 群组",
        r"No \(kind) container named \(path.identifier). Use the apps tool to list the containers you can use.": r"找不到名为 \(path.identifier) 的\(kind)容器。请使用 apps 工具查看可访问的容器。",
        r"\(name) can't be used outside the workspace.": r"\(name) 不能在工作区以外使用。",
    },
    "Sources/StupidAgentCore/SQLiteTool.swift": {
        "Query database": "查询数据库",
        "Path to the database file (workspace or /apps/… or /app-groups/…)": "数据库文件路径（工作区或 /apps/…、/app-groups/…）",
        "One read-only SQL statement (SELECT, WITH, PRAGMA, EXPLAIN). Omit it to list tables and views.": "一条只读 SQL 语句（SELECT、WITH、PRAGMA、EXPLAIN），留空则列出表和视图。",
        r"Maximum rows to return (default \(defaultLimit), at most \(maximumLimit))": r"返回的最大行数（默认 \(defaultLimit)，最多 \(maximumLimit)）",
        r"File not found: \(path)": r"找不到文件：\(path)",
        r"\(path) is a directory. Use ls to find the database file.": r"\(path) 是目录。请使用 ls 查找数据库文件。",
        r"\(result.rows.count) row(s)\n\(String(decoding: data, as: UTF8.self))": r"共 \(result.rows.count) 行\n\(String(decoding: data, as: UTF8.self))",
        r"\n\n[Truncated to \(limit) rows or \(maximumBytes / 1024)KB. Narrow the query or raise limit.]": r"\n\n[结果已截断至 \(limit) 行或 \(maximumBytes / 1024)KB。请缩小查询范围或提高上限。]",
        r"Couldn't open \(url.lastPathComponent) as a SQLite database.": r"无法将 \(url.lastPathComponent) 作为 SQLite 数据库打开。",
        r"Couldn't make \(url.lastPathComponent) read-only: \(sqliteError(database))": r"无法以只读方式打开 \(url.lastPathComponent)：\(sqliteError(database))",
        r"SQLite error: \(sqliteError(database))": r"SQLite 错误：\(sqliteError(database))",
        "Only one statement can run at a time.": "一次只能执行一条语句。",
        r"Only read-only statements are allowed. \(url.lastPathComponent) was opened read-only.": r"仅允许只读语句。\(url.lastPathComponent) 已以只读方式打开。",
        "The query took too long and was stopped.": "查询超时，已停止。",
        "Unknown SQLite error": "未知 SQLite 错误",
    },
}

def replace_literal(source: str, old: str, new: str) -> tuple[str, bool]:
    original = '"' + old + '"'
    replacement = '"' + new + '"'
    return source.replace(original, replacement), original in source

def localize_app() -> None:
    missed = []
    total = 0
    for relative, pairs in APP.items():
        path = ROOT / relative
        source = path.read_text(encoding="utf-8")
        for old, new in pairs.items():
            source, found = replace_literal(source, old, new)
            if found:
                total += 1
            else:
                missed.append(f"{relative}: {old}")
        path.write_text(source, encoding="utf-8")

    # 原始 New chat 是持久化数据的哨兵：保留其内部值，只汉化显示。
    conv = ROOT / "Sources/StupidAgent/ConversationsView.swift"
    source = conv.read_text(encoding="utf-8")
    source = source.replace('Text(conversation.title)', 'Text(conversation.title == "New chat" ? "新对话" : conversation.title)')
    source = source.replace('date.formatted(.dateTime.weekday(.wide))',
                            'date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN")))')
    source = source.replace('date.formatted(date: .numeric, time: .omitted)',
                            'date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))')
    conv.write_text(source, encoding="utf-8")

    adapter = ROOT / "Sources/StupidAgent/AgentChatAdapter.swift"
    source = adapter.read_text(encoding="utf-8")
    source = source.replace('ChatInfo(title: session.conversation.title,',
                            'ChatInfo(title: session.conversation.title == "New chat" ? "新对话" : session.conversation.title,')
    adapter.write_text(source, encoding="utf-8")

    settings = ROOT / "Sources/StupidAgent/SettingsView.swift"
    source = settings.read_text(encoding="utf-8")
    source = source.replace('Text(level.rawValue.capitalized)', 'Text(thinkingName(level))')
    source = source.replace('    /// A picked provider brings its base URL;',
'''    private func thinkingName(_ level: ThinkingLevel) -> String {
        switch level {
        case .off: return "关闭"
        case .minimal: return "极低"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    /// A picked provider brings its base URL;''')
    settings.write_text(source, encoding="utf-8")

    agent = ROOT / "Sources/StupidAgentCore/AgentSession.swift"
    source = agent.read_text(encoding="utf-8")
    source = source.replace('    You are stupid agent, an assistant', '    除非用户指定其他语言，否则请始终使用简体中文回答，保持技术术语和代码原样。\\n    You are stupid agent, an assistant')
    agent.write_text(source, encoding="utf-8")

    title = ROOT / "Sources/StupidAgentCore/TitleGenerator.swift"
    source = title.read_text(encoding="utf-8")
    source = source.replace('    You name chat conversations. Reply with only a short title, at most six words, for the conversation that starts \\',
                            '    请根据用户第一条消息生成简短的简体中文对话标题（不超过 12 个汉字）。只返回标题，不要引号、Markdown 或结尾标点。\\')
    source = source.replace('["Title:", "title:", "#"]', '["Title:", "title:", "标题：", "标题:", "#"]')
    title.write_text(source, encoding="utf-8")

    welcome = ROOT / "Sources/StupidAgent/StupidAgent.swift"
    source = welcome.read_text(encoding="utf-8")
    source = source.replace("# Welcome", "# 欢迎使用")
    source = source.replace("This folder is the agent's workspace. The agent can read, create and edit files here, and you can see \\",
                            "此文件夹是智能体的工作区。智能体可在这里读取、新建和修改文件，你可以在“文件”App 中查看 \\")
    source = source.replace("them in the Files app under On My iPhone → stupid agent.",
                            "这些文件，路径为“我的 iPhone”→ stupid agent。")
    welcome.write_text(source, encoding="utf-8")

    info = ROOT / "Info.plist"
    source = info.read_text(encoding="utf-8")
    source = source.replace("<string>stupid agent</string>", "<string>随身智能体</string>")
    source = source.replace("Connect to a model running on a computer on your network, such as Ollama or LM Studio.",
                            "连接同一局域网内电脑运行的模型，例如 Ollama 或 LM Studio。")
    source = source.replace("<key>CFBundleDisplayName</key>", "<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>\\n\\t<key>CFBundleLocalizations</key><array><string>zh-Hans</string></array>\\n\\t<key>CFBundleDisplayName</key>")
    source = source.replace("<key>NSLocalNetworkUsageDescription</key>",
                            "<key>NSMicrophoneUsageDescription</key><string>用于录制并发送语音消息。</string>\\n\\t<key>NSPhotoLibraryAddUsageDescription</key><string>将聊天中的图片保存到照片图库。</string>\\n\\t<key>NSLocalNetworkUsageDescription</key>")
    info.write_text(source, encoding="utf-8")

    # 修改了工具名称后，更新单元测试的预期值，确保汉化不掩盖回归。
    tests = ROOT / "Tests/StupidAgentCoreTests/StupidAgentCoreTests.swift"
    source = tests.read_text(encoding="utf-8")
    for old, new in {
        '"Read notes.md"': '"读取 notes.md"',
        '"List"': '"列出"',
        '"Search the web for swift 6"': '"网页搜索 swift 6"',
        '"Run JavaScript"': '"运行 JavaScript"',
    }.items():
        source = source.replace(old, new)
    tests.write_text(source, encoding="utf-8")
    if missed:
        print("未命中翻译（需要人工复查）:")
        for item in missed:
            print("  " + item)
    print(f"已处理主 App 汉化词条 {total} 条，涉及 {len(APP)} 个源文件。")

if __name__ == "__main__":
    localize_app()
