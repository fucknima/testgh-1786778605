#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""汉化构建过程中 SwiftPM 下载的 stupid-chatkit 源码。

只替换用户可见文本，保留图标名、模型名、协议、消息 ID、数据结构和功能。
由 scripts/patch-chatkit.py 在临时依赖检出目录内调用。
"""
from pathlib import Path
import stat

KIT = {
    "ChatKit.swift": {
        "In 5 Minutes": "5 分钟后",
        "In 30 Minutes": "30 分钟后",
        "In 1 Hour": "1 小时后",
        "In 3 Hours": "3 小时后",
    },
    "Models/AdapterChatViewModel.swift": {
        "That message is too far back to show.": "该消息时间过早，无法显示。",
        "That message is no longer available.": "该消息已不可用。",
    },
    "Models/ChatForward.swift": {
        r"Forwarded from \($0)": r"转发自 \($0)",
        "Voice Message.m4a": "语音消息.m4a",
        "This chat can't take photos or files.": "此对话不支持发送图片或文件。",
        "The recording couldn't be converted to send as a file.": "录音无法转换为可发送的文件。",
    },
    "Models/ChatListViewModel.swift": {
        r"You: \(body)": r"我：\(body)",
    },
    "Models/ChatViewModel.swift": {
        r"last seen \(Self.lastSeenTime(date))": r"上次在线：\(Self.lastSeenTime(date))",
        "last seen recently": "最近在线",
        "last seen within a week": "一周内在线",
        "last seen within a month": "一个月内在线",
        "last seen a long time ago": "很久没有上线",
        "just now": "刚刚",
        "Message deleted": "消息已删除",
        "Voice message": "语音消息",
        "This message can't be forwarded.": "此消息无法转发。",
        r"Shared “\(title)”": r"分享了“\(title)”",
    },
    "Views/ChatAudioPreview.swift": {
        r"Play Preview of \(title)": r"播放 \(title) 的预览",
        "Pause Preview": "暂停预览",
        "No Preview Available": "暂无预览",
        "Play Preview": "播放预览",
        "Pause Voice Message": "暂停语音",
        "Voice Message Unavailable": "语音不可用",
        "Play Voice Message": "播放语音",
    },
    "Views/ChatImageViewer.swift": {
        "Save to Photos": "保存到相册",
        "Saved to Photos": "已保存到相册",
        "Allow stupid social to add photos in Settings to save images.": "请在系统设置中允许本 App 将图片添加到相册。",
        "Couldn't Save Image": "保存图片失败",
        "Profile Photo": "头像",
        "Profile photo": "头像",
    },
    "Views/ChatMessageFocusView.swift": {
        "Remind Me": "提醒我",
    },
    "Views/ChatReactionGridView.swift": {
        "Search Emoji": "搜索表情",
    },
    "Views/ChatStickerPanel.swift": {
        r"Stickers for \(emoji)": r"\(emoji) 的贴纸",
        "Stickers you add in Telegram show here.": "从 Telegram 添加的贴纸将显示在这里。",
        r"Couldn't load stickers. \(error.localizedDescription)": r"加载贴纸失败：\(error.localizedDescription)",
        r"No stickers for \(selectedEmoji)": r"没有与 \(selectedEmoji) 对应的贴纸",
    },
    "Views/ChatVoiceRecorder.swift": {
        "Allow microphone access in Settings to record voice messages.": "请在系统设置中允许使用麦克风，以便录制语音消息。",
        "The microphone couldn't start recording.": "麦克风无法开始录音。",
    },
    "Views/ChatView.swift": {
        "Redacted": "内容已隐藏",
        "Search Messages": "搜索消息",
    },
    "Views/ChatMessageCell.swift": {
        "Today": "今天",
        "Yesterday": "昨天",
        "New Messages": "以下为新消息",
        r"\(names[0]) and \(names[1])": r"\(names[0]) 和 \(names[1])",
        r"\(names[0]) and \(names.count - 1) others": r"\(names[0]) 和其他 \(names.count - 1) 人",
        r"\(who) are typing": r"\(who) 正在输入",
        r"\(who) is typing": r"\(who) 正在输入",
        r"edited \(time)": r"已编辑 \(time)",
        r"\(shownTime), Sent": r"\(shownTime)，已发送",
        r"\(shownTime), Seen": r"\(shownTime)，已读",
        "Sending": "发送中",
        "Message deleted": "消息已删除",
        "Reminder due": "提醒时间已到",
        "Due in ": "剩余 ",
        "Uploading…": "上传中…",
        "Shows less": "收起内容",
        "Shows the whole message": "展开全部消息",
    },
    "Views/ChatUIKitView.swift": {
        "Reconnect": "重新连接",
        "Add Attachment": "添加附件",
        "Message": "消息",
        "Send": "发送",
        "Stickers": "贴纸",
        "Record Voice Message": "录制语音消息",
        "Previous Result": "上一个结果",
        "Next Result": "下一个结果",
        "Searching…": "正在搜索…",
        "No results yet": "暂无搜索结果",
        "No results": "没有找到结果",
        "Read only": "只读",
        "Reply": "回复",
        "Message unavailable": "消息不可用",
        "Loading…": "加载中…",
        "Disconnected": "连接已断开",
        "Edit Message": "编辑消息",
        "Cancel Editing": "取消编辑",
        "Cancel Forward": "取消转发",
        "Cancel Reply": "取消回复",
        "Stop": "停止",
        "Save": "保存",
        "Photo Library": "照片图库",
        "Files": "文件",
        "Delete Recording": "删除录音",
        "Send Voice Message": "发送语音",
        " Slide to cancel": " 左滑取消",
        "Slide left to cancel": "向左滑动取消",
        "Hold to record, release to send.": "按住录音，松开发送。",
        "Recording, ": "正在录音，",
        "Keyboard": "键盘",
        "Attached Image": "附加图片",
        "Remove Attachment": "移除附件",
        "Drop to Attach": "拖放以添加附件",
        r"Couldn't play the video: \(error.localizedDescription)": r"无法播放视频：\(error.localizedDescription)",
        r"Couldn't open \(filename): \(error.localizedDescription)": r"无法打开 \(filename)：\(error.localizedDescription)",
        "More Reactions": "更多回应",
        "Forward": "转发",
        "Edit": "编辑",
        "Copy": "复制",
        "Copy Link": "复制链接",
        "Mark as Done": "标记完成",
        "Custom…": "自定义…",
        "Remind Me": "提醒我",
        "Delete": "删除",
        "Copied": "已复制",
        "OK": "确定",
        "Open Link?": "打开链接？",
        "Cancel": "取消",
        "Open": "打开",
        "Jump to Latest": "跳到最新消息",
        "Next Unseen Reaction": "下一条未读回应",
        "Reminder Not Set": "未能设置提醒",
        "Delete Message?": "删除消息？",
        "This deletes the message for everyone in the chat.": "删除后，这条消息将对聊天中的所有人不可见。",
        "Delete Message": "删除消息",
        "You": "我",
    },
}

def localize_chatkit(root: Path) -> None:
    missed = []
    total = 0
    for relative, pairs in KIT.items():
        path = root / relative
        if not path.is_file():
            raise FileNotFoundError(f"ChatKit 源文件缺失：{path}")
        source = path.read_text(encoding="utf-8")
        original = source
        for old, new in pairs.items():
            token = '"' + old + '"'
            translated = '"' + new + '"'
            if token in source:
                source = source.replace(token, translated)
                total += 1
            else:
                missed.append(f"{relative}: {old}")
        if relative == "Views/ChatUIKitView.swift":
            # 插值中包含内层引号的文本单独处理，避免改变代码结构。
            source = source.replace('Forward from \\(ChatRedaction.name(', '转发自 \\(ChatRedaction.name(')
            source = source.replace('Reply to \\(ChatRedaction.name(', '回复 \\(ChatRedaction.name(')
            source = source.replace(') of \\(count)', ') / \\(count)')
            source = source.replace(') of \\(count)', ') / \\(count)')
        if relative == "Views/ChatMessageCell.swift":
            source = source.replace('"Due in "', '"剩余 "')
        if source != original:
            path.chmod(path.stat().st_mode | stat.S_IWUSR)
            path.write_text(source, encoding="utf-8")
    if missed:
        print("ChatKit 未匹配的英文词条（建议人工复查）：")
        for entry in missed:
            print("  " + entry)
    print(f"已应用 ChatKit 简体中文翻译：{total} 条，覆盖 {len(KIT)} 个文件。")

if __name__ == "__main__":
    root = Path(".build/stupid-app/scratch/arm64-apple-ios/StupidAgent/checkouts/stupid-chatkit/Sources/StupidChatKit")
    localize_chatkit(root)
