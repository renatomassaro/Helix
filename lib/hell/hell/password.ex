defmodule HELL.Password do

  def generate(:verification_key) do
    [alpha: 3, digit: 3]
    |> Burette.Internet.password()
    |> String.downcase()
  end

  def generate(:server),
    do: Burette.Internet.password alpha: 8, digit: 4

  def generate(:bank_account),
    do: Burette.Internet.password alpha: 8
end
