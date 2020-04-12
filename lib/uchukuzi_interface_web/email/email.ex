defmodule UchukuziInterfaceWeb.Email.Email do
  import Bamboo.Email
  alias UchukuziInterfaceWeb.EmailView

  use Uchukuzi.Roles.Model

  def send_token_email_to(%CrewMember{} = assistant, token) do
    new_email(
      to: assistant.email,
      from: "support@uchukuzi.com",
      subject: "Uchukuzi Assistant Login Link",
      html_body: EmailView.render_html(assistant, token),
      text_body: EmailView.render_text(assistant, token)
    )
  end
end
