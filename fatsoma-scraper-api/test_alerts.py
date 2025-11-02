#!/usr/bin/env python3
"""
Test script for email alerting system
Run this to verify your email configuration is working
"""

from alerting import EmailAlerter
import sys

def main():
    print("🧪 Testing Email Alert System")
    print("=" * 50)

    alerter = EmailAlerter()

    # Check configuration
    print("\n📋 Configuration Check:")
    print(f"   SMTP Server: {alerter.smtp_server}:{alerter.smtp_port}")
    print(f"   From: {alerter.sender_email}")
    print(f"   To: {alerter.recipient_email}")
    print(f"   Configured: {'✅ Yes' if alerter.is_configured() else '❌ No'}")

    if not alerter.is_configured():
        print("\n❌ Email alerting is not configured!")
        print("\nTo configure email alerts:")
        print("1. Copy .env.example to .env")
        print("2. Add your email settings:")
        print("   - ALERT_EMAIL_FROM=your-email@gmail.com")
        print("   - ALERT_EMAIL_PASSWORD=your-app-password")
        print("   - ALERT_EMAIL_TO=recipient@email.com")
        print("\n⚠️  For Gmail, you need an App Password:")
        print("   https://myaccount.google.com/apppasswords")
        sys.exit(1)

    # Send test alert
    print("\n📧 Sending test email...")
    success = alerter.send_test_alert()

    if success:
        print("\n✅ Test email sent successfully!")
        print(f"Check your inbox at: {alerter.recipient_email}")
    else:
        print("\n❌ Failed to send test email")
        print("Check the error message above and verify your configuration")
        sys.exit(1)

if __name__ == "__main__":
    main()
