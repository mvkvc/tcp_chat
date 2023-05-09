defmodule FakeSlack.Repo.Bans do
  use Ecto.Schema

  schema "admin" do
    field(:room, :string)
    field(:username, :string)
    field(:expiry, :integer)
  end

  def changeset(ban, params \\ %{}) do
    ban
    |> cast(params, [:room, :username, :expiry])
    |> validate_required([:room, :username, :expiry])
  end
end
