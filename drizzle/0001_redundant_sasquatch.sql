ALTER TABLE "user" ADD COLUMN "google_id" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;--> statement-breakpoint
ALTER TABLE "user" DROP COLUMN "age";--> statement-breakpoint
ALTER TABLE "user" ADD CONSTRAINT "user_google_id_unique" UNIQUE("google_id");