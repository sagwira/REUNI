import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from typing import Dict, List
import os
from dotenv import load_dotenv
import logging

load_dotenv()

logger = logging.getLogger(__name__)

class EmailAlerter:
    """Send email alerts for scraper failures"""

    def __init__(self):
        # Email configuration from environment variables
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
        self.sender_email = os.getenv('ALERT_EMAIL_FROM')
        self.sender_password = os.getenv('ALERT_EMAIL_PASSWORD')
        self.recipient_email = os.getenv('ALERT_EMAIL_TO')

        # Alert settings
        self.min_events_threshold = int(os.getenv('MIN_EVENTS_THRESHOLD', '3'))
        self.alert_on_zero_events = os.getenv('ALERT_ON_ZERO_EVENTS', 'true').lower() == 'true'

    def is_configured(self) -> bool:
        """Check if email alerting is properly configured"""
        return all([
            self.sender_email,
            self.sender_password,
            self.recipient_email
        ])

    def send_alert(self, subject: str, body: str, error_details: Dict = None):
        """Send an email alert"""
        if not self.is_configured():
            logger.warning("⚠️  Email alerting not configured. Skipping alert.")
            logger.info(f"Alert would have been sent:\nSubject: {subject}\nBody: {body}")
            return False

        try:
            # Create message
            message = MIMEMultipart("alternative")
            message["Subject"] = f"[Fatsoma Scraper Alert] {subject}"
            message["From"] = self.sender_email
            message["To"] = self.recipient_email

            # Create HTML body
            html_body = self._create_html_body(subject, body, error_details)

            # Attach both plain text and HTML
            text_part = MIMEText(body, "plain")
            html_part = MIMEText(html_body, "html")
            message.attach(text_part)
            message.attach(html_part)

            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.sender_email, self.sender_password)
                server.send_message(message)

            logger.info(f"✅ Alert email sent successfully to {self.recipient_email}")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to send alert email: {str(e)}")
            return False

    def _create_html_body(self, subject: str, body: str, error_details: Dict = None) -> str:
        """Create formatted HTML email body"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        html = f"""
        <html>
          <head>
            <style>
              body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
              .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
              .header {{ background: #d32f2f; color: white; padding: 20px; border-radius: 5px 5px 0 0; }}
              .content {{ background: #f9f9f9; padding: 20px; border: 1px solid #ddd; }}
              .footer {{ background: #f1f1f1; padding: 10px; text-align: center; font-size: 12px; color: #666; }}
              .error-box {{ background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 15px 0; }}
              .metric {{ display: inline-block; margin: 10px 15px 10px 0; padding: 10px; background: white; border-radius: 5px; }}
              .metric-label {{ font-size: 12px; color: #666; }}
              .metric-value {{ font-size: 24px; font-weight: bold; color: #d32f2f; }}
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>🚨 Fatsoma Scraper Alert</h2>
                <p style="margin: 0;">{timestamp}</p>
              </div>
              <div class="content">
                <h3>{subject}</h3>
                <p>{body}</p>
        """

        if error_details:
            html += '<div class="error-box"><h4>Error Details:</h4>'

            if 'metrics' in error_details:
                metrics = error_details['metrics']
                html += '<div style="margin: 15px 0;">'
                html += f'''
                    <div class="metric">
                        <div class="metric-label">Success Rate</div>
                        <div class="metric-value">{metrics.get('success_rate', 'N/A')}</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Failed Scrapes</div>
                        <div class="metric-value">{metrics.get('failed', 0)}</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Total Events</div>
                        <div class="metric-value">{metrics.get('total_events', 0)}</div>
                    </div>
                '''
                html += '</div>'

            if 'recent_errors' in error_details:
                html += '<h4>Recent Errors:</h4><ul>'
                for error in error_details['recent_errors']:
                    html += f'<li>{error}</li>'
                html += '</ul>'

            if 'city' in error_details:
                html += f'<p><strong>City:</strong> {error_details["city"]}</p>'

            if 'event_count' in error_details:
                html += f'<p><strong>Events Scraped:</strong> {error_details["event_count"]}</p>'

            html += '</div>'

        html += """
              </div>
              <div class="footer">
                <p>This is an automated alert from your Fatsoma Event Scraper</p>
                <p>Check your logs for more details: scraper.log</p>
              </div>
            </div>
          </body>
        </html>
        """

        return html

    def alert_scrape_failure(self, city: str, error: str, metrics: Dict):
        """Send alert for complete scrape failure"""
        subject = f"Scrape Failed for {city}"
        body = f"""
The scraper failed to retrieve events for {city}.

Error: {error}

This could indicate:
- Network issues
- Fatsoma website changes
- Rate limiting / IP ban
- Server downtime

Please check the logs and investigate.
        """

        error_details = {
            'city': city,
            'error': error,
            'metrics': metrics,
            'recent_errors': metrics.get('recent_errors', [])
        }

        self.send_alert(subject, body, error_details)

    def alert_low_event_count(self, city: str, event_count: int, metrics: Dict):
        """Send alert when event count is unusually low"""
        subject = f"Low Event Count for {city}"
        body = f"""
The scraper found only {event_count} events for {city}, which is below the expected threshold of {self.min_events_threshold}.

This might indicate:
- HTML structure changes on Fatsoma
- Incorrect selectors
- Events being filtered out unexpectedly

Recent scrape success rate: {metrics.get('success_rate', 'N/A')}

Please review the scraper logs and verify the site structure.
        """

        error_details = {
            'city': city,
            'event_count': event_count,
            'metrics': metrics,
            'recent_errors': metrics.get('recent_errors', [])
        }

        self.send_alert(subject, body, error_details)

    def alert_no_event_cards(self, city: str, metrics: Dict):
        """Send alert when no event cards are found (likely HTML structure change)"""
        subject = f"🔴 CRITICAL: HTML Structure Change Detected"
        body = f"""
CRITICAL ISSUE: No event cards found for {city}.

This strongly indicates that Fatsoma has changed their HTML structure.

The event card selectors are no longer matching. You need to:
1. Visit https://www.fatsoma.com/e/{city}
2. Inspect the HTML structure
3. Update the selectors in scraper.py

The scraper will continue to fail until this is fixed.
        """

        error_details = {
            'city': city,
            'metrics': metrics,
            'recent_errors': metrics.get('recent_errors', [])
        }

        self.send_alert(subject, body, error_details)

    def send_test_alert(self):
        """Send a test alert to verify configuration"""
        subject = "Test Alert"
        body = """
This is a test alert from your Fatsoma scraper.

If you're receiving this email, your alert system is configured correctly!

Configuration:
- SMTP Server: {self.smtp_server}
- SMTP Port: {self.smtp_port}
- From: {self.sender_email}
- To: {self.recipient_email}

You can safely ignore this message.
        """

        return self.send_alert(subject, body)
