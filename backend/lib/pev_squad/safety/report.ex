defmodule PevSquad.Safety.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @reasons [
    spam: "Spam or advertising",
    offensive: "Offensive or hateful",
    harassment: "Harassment or bullying",
    dangerous: "Dangerous riding or illegal activity",
    private_info: "Shares someone's private information",
    not_theirs: "Not theirs — copied photo or impersonation",
    other: "Something else"
  ]

  schema "reports" do
    field :target_type, Ecto.Enum, values: [:review, :photo, :profile]
    field :target_id, :integer
    field :reason, Ecto.Enum, values: Keyword.keys(@reasons)
    field :notes, :string
    field :status, Ecto.Enum, values: [:open, :resolved, :dismissed], default: :open
    field :resolution, :string
    field :resolved_at, :utc_datetime

    belongs_to :reporter, PevSquad.Accounts.User
    belongs_to :target_user, PevSquad.Accounts.User
    belongs_to :resolved_by, PevSquad.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def reasons, do: @reasons
  def reason_label(reason), do: Keyword.fetch!(@reasons, reason)

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reason, :notes])
    |> validate_required([:reason], message: "pick a reason")
    |> validate_length(:notes, max: 1000)
    |> unique_constraint([:reporter_id, :target_type, :target_id],
      name: :reports_one_open_per_reporter_index,
      error_key: :reason,
      message: "you've already reported this — the moderators are on it"
    )
  end
end
