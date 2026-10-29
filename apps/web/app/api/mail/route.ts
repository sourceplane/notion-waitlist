import { render } from "@react-email/render";
import { getCloudflareContext } from "@opennextjs/cloudflare";

import WelcomeTemplate from "../../../emails";

import { Resend } from "resend";
import { NextRequest, NextResponse } from "next/server";
import { allowed, notConnected, resendConfig, tooManyRequests } from "@/lib/waitlist";

export async function POST(request: NextRequest) {
  const config = resendConfig();
  if (!config) return notConnected("Resend");
  // 2 requests per minute from the same IP address (lib/waitlist.ts).
  if (!(await allowed(getCloudflareContext().env.SIGNUP_LIMITER, "mail", request))) {
    return tooManyRequests();
  }

  const { email, firstname } = await request.json();

  const resend = new Resend(config.apiKey);
  const { data, error } = await resend.emails.send({
    from: config.from,
    to: [email],
    subject: "Thankyou for wailisting the Next.js + Notion CMS template!",
    html: await render(WelcomeTemplate({ userFirstname: firstname })),
  });

  if (error) {
    return NextResponse.json(error, { status: 502 });
  }

  if (!data) {
    return NextResponse.json({ message: "Failed to send email" }, { status: 502 });
  }

  return NextResponse.json({ message: "Email sent successfully" });
}
