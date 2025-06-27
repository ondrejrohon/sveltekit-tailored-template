CREATE TABLE "email_verification_request" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"code" text NOT NULL,
	"email" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "email_verification_request" ADD CONSTRAINT "email_verification_request_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;