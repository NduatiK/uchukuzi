defmodule UchukuziInterfaceWeb.Email.Email do
  import Bamboo.Email
  alias UchukuziInterfaceWeb.EmailView

  use Uchukuzi.Roles.Model

  def send_token_email_to(%CrewMember{} = assistant, token) do
    new_email(
      to: assistant.email,
      from: "support@uchukuzi.com",
      subject: "Uchukuzi Assistant Login Link",
      html_body: EmailView.render_assistant_login("html", assistant, token),
      text_body: EmailView.render_assistant_login("text", assistant, token)
    )
  end

  def send_token_email_to(%Manager{} = manager, token) do
    new_email(
      to: manager.email,
      from: "support@uchukuzi.com",
      subject: "Uchukuzi Confirmation",
      html_body: EmailView.render_manager_signup("html", manager, token),
      text_body: EmailView.render_manager_signup("text", manager, token)
    )
  end
end
