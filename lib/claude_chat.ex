defmodule ClaudeChat do
  use Application

  def start(_type, _args) do
    children = [
      {Finch, name: ClaudeChat.Finch}
    ]

    opts = [strategy: :one_for_one, name: ClaudeChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def main(model) do
    {:ok, _} = Application.ensure_all_started(:claude_chat)

    IO.puts("Welcome to ClaudeChat! Using #{model} model. Type 'exit' to quit.")
    chat_loop([], model)
  end

  defp chat_loop(messages, model) do
    prompt = IO.gets("> ") |> String.trim()

    case prompt do
      "exit" ->
        IO.puts("Goodbye!")

      _ ->
        messages = messages ++ [%{role: "user", content: prompt}]

        case send_message(messages, model) do
          {:ok, response} ->
            IO.puts("\nAssistant: #{response}")
            messages = messages ++ [%{role: "assistant", content: response}]
            chat_loop(messages, model)

          {:error, error} ->
            IO.puts("\nError: #{inspect(error)}")
            chat_loop(messages, model)
        end
    end
  end

  defp send_message(messages, "openai") do
    body =
      Jason.encode!(%{
        model: "gpt-4o-mini",
        messages: messages
      })

    Finch.build(
      :post,
      "https://api.openai.com/v1/chat/completions",
      [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{System.get_env("OPENAI_API")}"}
      ],
      body
    )
    |> Finch.request(ClaudeChat.Finch)
    |> case do
      {:ok, response} ->
        case Jason.decode!(response.body) do
          %{"choices" => [%{"message" => %{"content" => text}} | _]} -> {:ok, text}
          error -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_message(messages, "claude") do
    body =
      Jason.encode!(%{
        model: "claude-3-5-haiku-latest",
        messages: messages,
        max_tokens: 1024
      })

    Finch.build(
      :post,
      "https://api.anthropic.com/v1/messages",
      [
        {"anthropic-version", "2023-06-01"},
        {"Content-Type", "application/json"},
        {"x-api-key", System.get_env("ANTHROPIC_API_KEY")}
      ],
      body
    )
    |> Finch.request(ClaudeChat.Finch)
    |> case do
      {:ok, response} ->
        case Jason.decode!(response.body) do
          %{"content" => [%{"text" => text} | _]} -> {:ok, text}
          error -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
