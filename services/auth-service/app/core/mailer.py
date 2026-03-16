from __future__ import annotations

import smtplib
from email.message import EmailMessage

from app.core.config import settings


def send_email(to_email: str, subject: str, body: str) -> None:
    if not settings.smtp_host or not settings.smtp_from:
        raise RuntimeError("SMTP не настроен: заполните SMTP_HOST и SMTP_FROM")

    msg = EmailMessage()
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)

    if settings.smtp_use_ssl:
        with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            if settings.smtp_user:
                server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)
        return

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
        if settings.smtp_use_tls:
            server.starttls()
        if settings.smtp_user:
            server.login(settings.smtp_user, settings.smtp_password)
        server.send_message(msg)
