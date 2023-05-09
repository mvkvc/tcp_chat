defmodule FakeSlack.Repo.Admin do
  use Ecto.Schema

  schema "admin" do
    field(:room, :string)
    field(:username, :string)
  end

  def changeset(admin, params \\ %{}) do
    admin
    |> cast(params, [:room, :username])
    |> validate_required([:room, :username])
  end
end
