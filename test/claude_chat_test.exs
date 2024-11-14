defmodule ClaudeChatTest do
  use ExUnit.Case
  doctest ClaudeChat

  test "greets the world" do
    assert ClaudeChat.hello() == :world
  end
end
