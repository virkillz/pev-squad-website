defmodule PevSquad.Reviews.Notifier do
  import Swoosh.Email
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Mailer
  alias PevSquad.Reviews.PevModel

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(subject)
      |> text_body(Mailer.framed(body))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_review_approved(review, url) do
    model = PevModel.full_name(review.pev_model)

    Mailer.in_locale(review.author, fn ->
      deliver(
        review.author.email,
        gettext("Your %{model} review is live", model: model),
        gettext(
          "Your review of the %{model} has been approved\nand is now on the Sheet:\n\n%{url}\n\nThanks for riding, and for writing it up.",
          model: model,
          url: url
        )
      )
    end)
  end

  def deliver_review_rejected(review, edit_url) do
    model = PevModel.full_name(review.pev_model)

    Mailer.in_locale(review.author, fn ->
      deliver(
        review.author.email,
        gettext("Your %{model} review needs changes", model: model),
        gettext(
          "A moderator sent your review of the %{model}\nback with this note:\n\n  %{note}\n\nEdit and resubmit it here:\n\n%{url}",
          model: model,
          note: review.rejection_reason,
          url: edit_url
        )
      )
    end)
  end
end
