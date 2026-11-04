defmodule PevSquad.Reviews.Notifier do
  import Swoosh.Email

  alias PevSquad.Mailer
  alias PevSquad.Reviews.PevModel

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_review_approved(review, url) do
    deliver(
      review.author.email,
      "Your #{PevModel.full_name(review.pev_model)} review is live",
      """

      ==============================

      Your review of the #{PevModel.full_name(review.pev_model)} has been approved
      and is now on the Sheet:

      #{url}

      Thanks for riding, and for writing it up.

      ==============================
      """
    )
  end

  def deliver_review_rejected(review, edit_url) do
    deliver(
      review.author.email,
      "Your #{PevModel.full_name(review.pev_model)} review needs changes",
      """

      ==============================

      A moderator sent your review of the #{PevModel.full_name(review.pev_model)}
      back with this note:

        #{review.rejection_reason}

      Edit and resubmit it here:

      #{edit_url}

      ==============================
      """
    )
  end
end
