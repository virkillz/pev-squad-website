defmodule PevSquad.Reviews.Score do
  @moduledoc """
  A 0–10 score with one decimal (9.4), stored as integer tenths (94) so
  sorting and averaging in SQL stay exact.
  """
  use Ecto.Type

  def type, do: :integer

  def cast(value) when is_integer(value), do: check(value * 1.0)
  def cast(value) when is_float(value), do: check(value)

  def cast(value) when is_binary(value) do
    case Float.parse(String.replace(String.trim(value), ",", ".")) do
      {float, ""} -> check(float)
      _ -> :error
    end
  end

  def cast(_), do: :error

  defp check(float) when float >= 0 and float <= 10, do: {:ok, Float.round(float, 1)}
  defp check(_), do: {:error, message: "must be between 0 and 10"}

  def load(tenths) when is_integer(tenths), do: {:ok, tenths / 10}
  def dump(score) when is_float(score), do: {:ok, round(score * 10)}
  def dump(score) when is_integer(score), do: {:ok, score * 10}
  def dump(_), do: :error

  @doc "Average of the given scores, rounded to one decimal; nil when empty."
  def average([]), do: nil
  def average(scores), do: Float.round(Enum.sum(scores) / length(scores), 1)
end
