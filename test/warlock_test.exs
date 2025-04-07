defmodule WarlockTest do
  use ExUnit.Case
  doctest Warlock

  test "greets the world" do
    assert Warlock.hello() == :world
  end
end
