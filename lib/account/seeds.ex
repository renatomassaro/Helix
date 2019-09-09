defmodule Helix.Account.Seeds do

  alias HELL.DateUtils
  alias Helix.Account.Model.Document
  alias Helix.Account.Repo

  def seed do
    document_seed()
  end

  # Populate the initial TOS and PP
  def document_seed do
    current_tos =
      :tos
      |> Document.Query.by_current()
      |> Repo.one()

    unless current_tos do
      tos_content_raw = "Todo"
      tos_content_html = "<p>Todo</p>"

      initial_tos_params =
        %{
          document_id: :tos,
          revision_id: 1,
          content_raw: tos_content_raw,
          content_html: tos_content_html,
          diff_raw: "No diff (initial version)",
          diff_html: "<p>No diff (initial version)</p>",
          update_reason: "Initial version",
          enforced_from: DateUtils.utc_now(:second)
        }

      initial_tos_params
      |> Document.create_changeset()
      |> Document.set_as_current()
      |> Repo.insert!()
    end

    current_pp =
      :pp
      |> Document.Query.by_current()
      |> Repo.one()

    unless current_pp do
      pp_content_raw = "Todo"
      pp_content_html = "<p>Todo</p>"

      initial_pp_params =
        %{
          document_id: :pp,
          revision_id: 1,
          content_raw: pp_content_raw,
          content_html: pp_content_html,
          diff_raw: "No diff (initial version)",
          diff_html: "<p>No diff (initial version)</p>",
          update_reason: "Initial version",
          enforced_from: DateUtils.utc_now(:second)
        }

      initial_pp_params
      |> Document.create_changeset()
      |> Document.set_as_current()
      |> Repo.insert!()
    end
  end
end
