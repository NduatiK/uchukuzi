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

  def send_token_email_to(%Guardian{} = guardian, token) do
    new_email(
      to: guardian.email,
      from: "support@uchukuzi.com",
      subject: "One Time Login",
      html_body: EmailView.render_guardian_login("html", guardian, token),
      text_body: EmailView.render_guardian_login("text", guardian, token)
    )
  end

  def send_token_email_to(%Student{} = student, token) do
    new_email(
      to: student.email,
      from: "support@uchukuzi.com",
      subject: "One Time Login",
      html_body: EmailView.render_student_login("html", student, token),
      text_body: EmailView.render_student_login("text", student, token)
    )
  end


  # def send_email_invite_to(%Student{} = student, token) do
  #   new_email(
  #     to: student.email,
  #     from: "support@uchukuzi.com",
  #     subject: "One Time Login",
  #     html_body: EmailView.render_guardian_login("html", manager, token),
  #     text_body: EmailView.render_guardian_login("text", manager, token)
  #   )
  # end
end
