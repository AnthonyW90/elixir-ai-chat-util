defmodule Mix.Tasks.Chat do
  use Mix.Task

  def run(args) do
    {opts, _remaining_args, _invalid} =
      OptionParser.parse(args,
        switches: [
          # --model openai or --model claude
          model: :string,
          # --help
          help: :boolean
        ],
        aliases: [
          # -m openai or -m claude
          m: :model,
          # -h
          h: :help
        ]
      )

    case opts do
      [help: true] ->
        show_help()

      [model: model] when model in ["openai", "claude"] ->
        ClaudeChat.main(model)

      # Default to openai if no model specified
      [] ->
        ClaudeChat.main("openai")

      _ ->
        IO.puts("Invalid model. Use --model openai or --model claude")
        show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Usage: mix chat [options]

    Options:
      --model, -m openai|claude  Choose the model to chat with
      --help, -h                 Show this help message

    Examples:
      mix chat --model openai
      mix chat -m claude
    """)
  end
end
