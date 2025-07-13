import { Recipient, EmailParams, MailerSend, Sender } from 'mailersend';
import { MAILERSEND_TOKEN } from '$env/static/private';

const mailerSend = new MailerSend({
	apiKey: MAILERSEND_TOKEN
});

interface EmailOptions {
	to: string;
	toName?: string;
	subject: string;
	html: string;
	from?: string;
	fromName?: string;
}

export async function sendEmail(options: EmailOptions) {
	try {
		const sentFrom = new Sender(
			options.from || 'noreply@ondrejrohon.com',
			options.fromName || 'Slova Test'
		);

		const recipients = [new Recipient(options.to, options.toName || options.to)];

		const emailParams = new EmailParams()
			.setFrom(sentFrom)
			.setTo(recipients)
			.setReplyTo(sentFrom)
			.setSubject(options.subject)
			.setHtml(options.html);

		const response = await mailerSend.email.send(emailParams);
		return { success: true, response };
	} catch (error) {
		console.error('Failed to send email:', error);
		return { success: false, error };
	}
}

export async function sendTestEmail() {
	return sendEmail({
		to: 'ondrej.rohon@gmail.com',
		subject: 'Test email',
		html: '<strong>This is the HTML content</strong>'
	});
}
