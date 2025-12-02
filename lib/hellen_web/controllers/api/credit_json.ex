defmodule HellenWeb.API.CreditJSON do
  alias Hellen.Billing.CreditTransaction

  def balance(%{balance: balance}) do
    %{data: %{credits: balance}}
  end

  def history(%{transactions: transactions}) do
    %{data: for(tx <- transactions, do: transaction_data(tx))}
  end

  defp transaction_data(%CreditTransaction{} = tx) do
    %{
      id: tx.id,
      amount: tx.amount,
      balance_after: tx.balance_after,
      reason: tx.reason,
      lesson_id: tx.lesson_id,
      inserted_at: tx.inserted_at
    }
  end
end
