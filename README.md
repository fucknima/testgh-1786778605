# stupid agent

An agent that runs on your iPhone with your own model. Point it at any OpenAI-compatible server (OpenAI, OpenRouter, Groq, DeepSeek, or Ollama and LM Studio on your computer), and it reads, writes, edits and searches files in its workspace folder, which you also see in the Files app. Tool calls run on the phone.

Built on [swift pi](https://github.com/stephancill/swift-pi), a Swift port of [pi](https://github.com/earendil-works/pi).

## Build

Requires the `stupid-app` CLI, 0.0.27 or later.

```sh
swift test                  # core tests
stupid-app run --simulator  # build, install and launch
```

The chat screen is [stupid chatkit](https://github.com/stephancill/stupid-chatkit).

## OpenCode Go

In Settings → Provider, select **OpenCode Go**. The app uses the official
Chat Completions endpoint and initially suggests `glm-5.3-flash`. Enter your
OpenCode Go key, choose Load Models, and save.

Every Go request, including title requests, uses a stable per-conversation
`x-opencode-session` plus `User-Agent: stupid-agent-ios/1.0`. The model catalog
is loaded from the separate `/inference/go/v1/models` endpoint.

The GitHub Actions build uploads an **unsigned** IPA which must be signed with
your own Apple certificate/profile before installing on a device.
