defmodule PevSquad.Safety.Report do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PevSquadWeb.Gettext

  # Labels are marked for extraction here and translated in reasons/0 and
  # reason_label/1, in the caller's locale.
  @reasons [
    spam: gettext_noop("Spam or advertising"),
    offensive: gettext_noop("Offensive or hateful"),
    harassment: gettext_noop("Harassment or bullying"),
    dangerous: gettext_noop("Dangerous riding or illegal activity"),
    private_info: gettext_noop("Shares someone's private information"),
    not_theirs: gettext_noop("Not theirs — copied photo or impersonation"),
    other: gettext_noop("Something else")
  ]

  schema "reports" do
    field :target_type, Ecto.Enum, values: [:review, :photo, :event, :profile]
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

  def reason_values, do: Keyword.keys(@reasons)
  def reasons, do: Enum.map(@reasons, fn {k, label} -> {k, translate(label)} end)
  def reason_label(reason), do: @reasons |> Keyword.fetch!(reason) |> translate()

  defp translate(label), do: Gettext.gettext(PevSquadWeb.Gettext, label)

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reason, :notes])
    |> validate_required([:reason], message: dgettext_noop("errors", "pick a reason"))
    |> validate_length(:notes, max: 1000)
    |> unique_constraint([:reporter_id, :target_type, :target_id],
      name: :reports_one_open_per_reporter_index,
      error_key: :reason,
      message: dgettext_noop("errors", "you've already reported this — the moderators are on it")
    )
  end
end
