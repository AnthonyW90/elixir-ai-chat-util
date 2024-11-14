defmodule ClaudeChat.History do
  @history_dir Path.expand("./.ai_chat/history")

  def init do
    File.mkdir_p!(@history_dir)
  end

  def save_chat(messages, model) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "chat+#{timestamp}_#{model}.json"
    path = Path.join([@history_dir, filename])

    chat_data = %{
      timestamp: timestamp,
      model: model,
      messages: messages
    }

    File.write!(path, Jason.encode!(chat_data, pretty: true))
    {:ok, filename}
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
