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

    IO.puts("""
    Welcome to AI Chat! Using #{model} model.
    Commands:
      /save          - Save current chat
      /list          - List saved chats
      /load <num>    - Load a saved chat
      /new           - Start a new chat
      /exit          - Quit the chat
    """)

    chat_loop([], model)
  end

  defp chat_loop(messages, model) do
    prompt = IO.gets("> ") |> String.trim()

    case prompt do
      "/exit" ->
        save_before_exit(messages, model)

      "/save" ->
        case ClaudeChat.History.save_chat(messages, model) do
          {:ok, filename} ->
            IO.puts("\nChat saved as #{filename}")
            chat_loop(messages, model)

          {:error, error} ->
            IO.puts("\nError: #{inspect(error)}")
            chat_loop(messages, model)
        end

      "/list" ->
        list_saved_chats()
        chat_loop(messages, model)

      "/load " <> num ->
        case Integer.parse(num) do
          {n, ""} ->
            load_chat(n)

          _ ->
            IO.puts("\nInvalid chat number")
            chat_loop(messages, model)
        end

      "/new" ->
        IO.puts("\nStarting a new chat...")
        chat_loop([], model)

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

  defp save_before_exit([], _model) do
    IO.puts("\nGoodbye!")
  end

  defp save_before_exit(messages, model) do
    IO.puts("Would you like to save the chat before exiting? (y/n)")

    case IO.gets("> ") |> String.trim() do
      "y" ->
        case ClaudeChat.History.save_chat(messages, model) do
          {:ok, filename} ->
            IO.puts("\nChat saved as #{filename}")
            IO.puts("Goodbye!")

          {:error, error} ->
            IO.puts("\nError: #{inspect(error)}")
            IO.puts("Goodbye!")
        end

      _ ->
        IO.puts("Goodbye!")
    end
  end

  defp list_saved_chats do
    chats = ClaudeChat.History.list_chats()

    IO.puts("\nSaved Chats:")

    chats
    |> Enum.with_index(1)
    |> Enum.each(fn {chat, index} ->
      IO.puts("""
      #{index}. #{chat.timestamp} (#{chat.model})
      #{chat.preview}
      """)
    end)
  end

  defp load_chat(number) do
    chats = ClaudeChat.History.list_chats()

    case Enum.at(chats, number - 1) do
      nil ->
        IO.puts("Chat number not found")
        chat_loop([], "openai")

      chat ->
        {messages, model} = ClaudeChat.History.load_chat(chat.filename)
        IO.puts("Loaded chat from #{chat.timestamp}")
        chat_loop(messages, model)
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
