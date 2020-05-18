defmodule UchukuziInterfaceWeb.EmailView do
  use UchukuziInterfaceWeb, :view

  if Mix.env() == :dev do
    # @website "http://10.0.2.2:4000"
    @website "http://localhost:4000"
    # @website "http://192.168.42.220:4000"
  else
    @website "https://uchukuzi.herokuapp.com"
  end

  def render_manager_signup("html", %Uchukuzi.Roles.Manager{} = manager, token) do
    link = "#{@website}/#/activate/?token=#{token}"
    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to activate your account. Use the button below to reset it.
    This password reset is only valid for the next <strong>1 hour.</strong>
    """

    renderHTML(
      manager.name,
      subline,
      body,
      link
    )
  end

  def render_manager_signup("text", %Uchukuzi.Roles.Manager{} = manager, token) do
    link = " #{@website}/#/activate/?token=#{token}"
    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to activate your account. Use the button below to reset it.
    This password reset is only valid for the next 1 hour.
    """

    renderText(manager.name, subline, body, link)
  end

  def render_assistant_login("html", %Uchukuzi.Roles.CrewMember{} = assistant, token) do
    link = "#{@website}/assistant_login?token=#{token}"

    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi Assistant account.
    Use the button below from your phone to access it.
    <strong>This link is only valid for the next 1 hour.</strong>
    """

    renderHTML(
      assistant.name,
      subline,
      body,
      link
    )
  end

  def render_assistant_login("text", %Uchukuzi.Roles.CrewMember{} = assistant, token) do
    link = "#{@website}/assistant_login?token=#{token}"
    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi Assistant account.
    Use the button below from your phone to access it.
    """

    renderText(assistant.name, subline, body, link)
  end

  def render_guardian_login("html", %Uchukuzi.Roles.Guardian{} = guardian, token) do
    link = "#{@website}/household_login?token=#{token}"

    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi account.
    Use the button below from your phone to access it.
    <strong>This link is only valid for the next 1 hour.</strong>
    """

    renderHTML(
      guardian.name,
      subline,
      body,
      link
    )
  end

  def render_guardian_login("text", %Uchukuzi.Roles.Guardian{} = guardian, token) do
    link = "#{@website}/household_login?token=#{token}"
    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi account.
    Use the button below from your phone to access it.
    """

    renderText(guardian.name, subline, body, link)
  end

  def render_student_login("html", %Uchukuzi.Roles.Student{} = student, token) do
    link = "#{@website}/household_login?token=#{token}"

    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi account.
    Use the button below from your phone to access it.
    <strong>This link is only valid for the next 1 hour.</strong>
    """

    renderHTML(
      student.name,
      subline,
      body,
      link
    )
  end

  def render_student_login("text", %Uchukuzi.Roles.Student{} = student, token) do
    link = "#{@website}/household_login?token=#{token}"
    subline = "Use this link to login. The link is only valid for 1 hours."

    body = """
    You recently requested to log into your Uchukuzi account.
    Use the button below from your phone to access it.
    """

    renderText(student.name, subline, body, link)
  end

  def renderText(name, subline, body, link) do
    """
    #{subline}

    Uchukuzi (#{@website})

    ************
    Hi #{name},
    ************

    #{body}

    Access account (#{link})

    Thanks,
    The Uchukuzi Team

    If you’re having trouble with the button above, copy and paste the URL below into your web browser.

    #{link}

    © 2020 Uchukuzi. All rights reserved.

    """
  end

  def renderHTML(name, subline, body, link) do
    """
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="x-apple-disable-message-reformatting" />
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title></title>

      </head>
      <body style="width: 100% !important; height: 100%; -webkit-text-size-adjust: none; font-family: Helvetica, Arial, sans-serif; background-color: #F4F4F7; color: #51545E; margin: 0;" bgcolor="#F4F4F7">
        <span class="preheader" style="display: none !important; visibility: hidden; mso-hide: all; font-size: 1px; line-height: 1px; max-height: 0; max-width: 0; opacity: 0; overflow: hidden;">
        #{subline}
        </span>
        <table class="email-wrapper" width="100%" cellpadding="0" cellspacing="0" role="presentation" style="width: 100%; -premailer-width: 100%; -premailer-cellpadding: 0; -premailer-cellspacing: 0; background-color: #F4F4F7; margin: 0; padding: 0;" bgcolor="#F4F4F7">
          <tr>
            <td align="center" style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px;">
              <table class="email-content" width="100%" cellpadding="0" cellspacing="0" role="presentation" style="width: 100%; -premailer-width: 100%; -premailer-cellpadding: 0; -premailer-cellspacing: 0; margin: 0; padding: 0;">
                <tr>
                  <td class="email-masthead" style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px; text-align: center; padding: 25px 0;" align="center">
                    <a href="#{@website}" class="f-fallback email-masthead_name" style="color: #A8AAAF; font-size: 16px; font-weight: bold; text-decoration: none; text-shadow: 0 1px 0 white;">
                    Uchukuzi
                  </a>
                  </td>
                </tr>
                <!-- Email Body -->
                <tr>
                  <td class="email-body" width="100%" cellpadding="0" cellspacing="0" style="word-break: break-word; margin: 0; padding: 0; font-family: Helvetica, Arial, sans-serif; font-size: 16px; width: 100%; -premailer-width: 100%; -premailer-cellpadding: 0; -premailer-cellspacing: 0; background-color: #FFFFFF;" bgcolor="#FFFFFF">
                    <table class="email-body_inner" align="center" width="570" cellpadding="0" cellspacing="0" role="presentation" style="width: 570px; -premailer-width: 570px; -premailer-cellpadding: 0; -premailer-cellspacing: 0; background-color: #FFFFFF; margin: 0 auto; padding: 0;" bgcolor="#FFFFFF">
                      <!-- Body content -->
                      <tr>
                        <td class="content-cell" style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px; padding: 35px;">
                          <div class="f-fallback">
                            <h1 style="margin-top: 0; color: #333333; font-size: 22px; font-weight: bold; text-align: left;" align="left">
                            Hi #{name},
    </h1>
                            <p style="font-size: 16px; line-height: 1.625; color: #51545E; margin: .4em 0 1.1875em;">
                            #{body}
                            </p>
                            <!-- Action -->
                            <table class="body-action" align="center" width="100%" cellpadding="0" cellspacing="0" role="presentation" style="width: 100%; -premailer-width: 100%; -premailer-cellpadding: 0; -premailer-cellspacing: 0; text-align: center; margin: 30px auto; padding: 0;">
                              <tr>
                                <td align="center" style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px;">

                                  <table width="100%" border="0" cellspacing="0" cellpadding="0" role="presentation">
                                    <tr>
                                      <td align="center" style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px;">
                                        <a href="#{link}" target="_blank" style="color: #FFF; border-color: rgba(30,165,145,1); border-style: solid; border-width: 10px 18px; background-color: rgba(30,165,145,1); display: inline-block; text-decoration: none; border-radius: 3px; box-shadow: 0 2px 3px rgba(0, 0, 0, 0.16); -webkit-text-size-adjust: none; box-sizing: border-box;">Access account</a>
                                      </td>
                                    </tr>
                                  </table>
                                </td>
                              </tr>
                            </table>
                            <p style="font-size: 16px; line-height: 1.625; color: #51545E; margin: .4em 0 1.1875em;">Thanks,
                              <br />The Uchukuzi Team</p>
                            <!-- Sub copy -->
                            <table class="body-sub" role="presentation" style="margin-top: 25px; padding-top: 25px; border-top-width: 1px; border-top-color: #EAEAEC; border-top-style: solid;">
                              <tr>
                                <td style="word-break: break-word; font-family: Helvetica, Arial, sans-serif; font-size: 16px;">
                                  <p class="f-fallback sub" style="font-size: 13px; line-height: 1.625; color: #6B6E76; margin: .4em 0 1.1875em;">If you’re having trouble with the button above, copy and paste the URL below into your phone's web browser.</p>

    <a href=#{link} style="font-size: 13px; line-height: 1.625; color: #6B6E76; margin: .4em 0 1.1875em;">
    #{link}
    </a>
                                </td>
                              </tr>
                            </table>
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end
end
