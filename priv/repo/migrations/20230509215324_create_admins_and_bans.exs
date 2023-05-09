defmodule FakeSlack.Repo.Migrations.CreateAdminsAndBans do
  use Ecto.Migration

  def change do
    create table(:admin) do
      add :room, :string
      add :username, :string
    end

    create table(:bans) do
      add :room, :string
      add :username, :string
      add :expiry, :integer
    end
  end
end
