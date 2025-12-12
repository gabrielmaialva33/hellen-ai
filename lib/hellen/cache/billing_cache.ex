defmodule Hellen.Cache.BillingCache do
  @moduledoc """
  Cache operations for Billing domain.

  Caches billing transactions, usage data, and related stats.

  ## TTL Strategy

  - Transactions list: 5 minutes (frequently viewed)
  - Usage data: 5 minutes (dashboard component)
  - Credit balance: 1 minute (needs accuracy for purchases)
  """

  alias Hellen.Cache
  alias Hellen.Cache.{Keys, UserCache}

  # TTLs
  @transactions_ttl :timer.minutes(5)
  @usage_ttl :timer.minutes(5)

  # ============================================================================
  # Transactions
  # ============================================================================

  @doc """
  Get user's transactions from cache or compute.
  """
  @spec get_transactions_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_transactions_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.billing_transactions(user_id), compute_fn, ttl: @transactions_ttl)
  end

  @doc """
  Invalidate transactions cache.
  """
  @spec invalidate_transactions(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_transactions(user_id) do
    Cache.delete(Keys.billing_transactions(user_id))
  end

  # ============================================================================
  # Usage Data
  # ============================================================================

  @doc """
  Get user's usage data from cache or compute.
  """
  @spec get_usage_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_usage_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.billing_usage(user_id), compute_fn, ttl: @usage_ttl)
  end

  @doc """
  Invalidate usage cache.
  """
  @spec invalidate_usage(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_usage(user_id) do
    Cache.delete(Keys.billing_usage(user_id))
  end

  # ============================================================================
  # Bulk Invalidation
  # ============================================================================

  @doc """
  Invalidate all billing-related caches for a user.
  """
  @spec invalidate_all(binary()) :: :ok
  def invalidate_all(user_id) do
    invalidate_transactions(user_id)
    invalidate_usage(user_id)
    :ok
  end

  @doc """
  Invalidate caches after a transaction is created.
  """
  @spec on_transaction_created(binary()) :: :ok
  def on_transaction_created(user_id) do
    invalidate_transactions(user_id)
    invalidate_usage(user_id)

    # Also invalidate user credits cache
    UserCache.invalidate_credits(user_id)
    :ok
  end
end
