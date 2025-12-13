defmodule Hellen.Repo.Migrations.EnableTimescaledbHypertables do
  @moduledoc """
  Habilita a extensão TimescaleDB para uso futuro.

  NOTA IMPORTANTE: A conversão para hypertables requer alteração das primary keys
  para incluir a coluna de tempo, o que quebra foreign keys existentes.

  Para implementar hypertables em produção, seria necessário:
  1. Criar novas tabelas com PKs compostas (id, inserted_at)
  2. Migrar dados
  3. Atualizar FKs em tabelas relacionadas
  4. Converter para hypertables

  Por enquanto, habilitamos apenas a extensão e funções do TimescaleDB
  para queries com time_bucket e outras funções úteis.
  """
  use Ecto.Migration

  def up do
    # Habilitar extensão TimescaleDB
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # Criar índices otimizados para queries temporais (sem hypertables)
    # Estes índices ajudam mesmo sem hypertables

    execute """
    CREATE INDEX IF NOT EXISTS analyses_inserted_at_brin
    ON analyses USING BRIN (inserted_at)
    """

    execute """
    CREATE INDEX IF NOT EXISTS credit_transactions_inserted_at_brin
    ON credit_transactions USING BRIN (inserted_at)
    """

    execute """
    CREATE INDEX IF NOT EXISTS bullying_alerts_inserted_at_brin
    ON bullying_alerts USING BRIN (inserted_at)
    """
  end

  def down do
    # Remover índices
    execute "DROP INDEX IF EXISTS analyses_inserted_at_brin"
    execute "DROP INDEX IF EXISTS credit_transactions_inserted_at_brin"
    execute "DROP INDEX IF EXISTS bullying_alerts_inserted_at_brin"

    # Nota: Não removemos a extensão timescaledb pois pode ter dependências
  end
end
