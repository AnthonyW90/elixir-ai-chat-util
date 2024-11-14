defmodule ClaudeChat.History do
  @history_dir Path.expand("./.ai_chat/history")

  def init do
    File.mkdir_p!(@history_dir)
  end

  def save_chat(messages, model) do
    name = generate_chat_name(messages, model)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    filename =
      "#{name}_#{timestamp}_#{model}.json"
      # Remove special chars
      |> String.replace(~r/[^\w\s-]/, "")
      # Replace spaces with underscores
      |> String.replace(~r/\s+/, "_")

    path = Path.join([@history_dir, filename])

    chat_data = %{
      timestamp: timestamp,
      model: model,
      messages: messages,
      name: name
    }

    File.write!(path, Jason.encode!(chat_data, pretty: true))
    {:ok, filename}
  end

  defp generate_chat_name(messages, model) do
    naming_prompt = [
      %{
        role: "system",
        content:
          "You are a chat naming assistant. Generate a brief, descriptive name (max 50 chars) for this chat based on its content. Return only the name, no explanation."
      },
      %{
        role: "user",
        content:
          "Based on this chat history, generate a concise, descriptive filename:\n#{summarize_chat(messages)}"
      }
    ]

    case ClaudeChat.send_message(naming_prompt, model) do
      {:ok, name} ->
        name |> String.trim() |> String.slice(0..49)

      {:error, _error} ->
        "untitled_chat"
    end
  end

  defp summarize_chat(messages) do
    messages
    |> Enum.map(fn msg ->
      "#{msg["role"]}: #{msg["content"]}"
    end)
    |> Enum.join("\n")
  end

  def list_chats do
    @history_dir
    |> File.ls!()
    |> Enum.sort(:desc)
    |> Enum.map(fn filename ->
      path = Path.join(@history_dir, filename)
      chat_data = path |> File.read!() |> Jason.decode!()
      preview = get_chat_preview(chat_data["messages"])

      %{
        filename: filename,
        name: chat_data["name"],
        timestamp: chat_data["timestamp"],
        model: chat_data["model"],
        preview: preview
      }
    end)
  end

  def load_chat(filename) do
    path = Path.join(@history_dir, filename)
    chat_data = path |> File.read!() |> Jason.decode!()
    {chat_data["messages"], chat_data["model"]}
  end

  defp get_chat_preview(messages) do
    messages
    |> Enum.take(-2)
    |> Enum.map_join("\n", fn msg ->
      content = String.slice(msg["content"], 0..50)
      "#{msg["role"]}: #{content}#{if String.length(msg["content"]) > 50, do: "...", else: ""}"
    end)
  end
end
