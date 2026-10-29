import { Client } from "@notionhq/client";
import { getCloudflareContext } from "@opennextjs/cloudflare";
import { NextResponse } from "next/server";
import { allowed, notConnected, notionConfig, tooManyRequests } from "@/lib/waitlist";

export async function POST(request: Request) {
  const config = notionConfig();
  if (!config) return notConnected("Notion");
  if (!(await allowed(getCloudflareContext().env.SIGNUP_LIMITER, "notion", request))) {
    return tooManyRequests();
  }

  const body = await request.json();
  try {
    const notion = new Client({
      auth: config.secret,
      baseUrl: config.baseUrl,
      // The Worker's own fetch. The client's default is node-fetch, and it
      // calls whatever it is given as a method of itself, which the Workers
      // runtime refuses for its native fetch ("Illegal invocation"), so the
      // call goes through a plain function.
      fetch: ((url: string, init: RequestInit) => fetch(url, init)) as never,
    });
    const response = await notion.pages.create({
      parent: {
        database_id: `${config.database}`,
      },
      properties: {
        Email: {
          type: "email",
          email: body?.email,
        },
        Name: {
          type: "title",
          title: [
            {
              type: "text",
              text: {
                content: body?.name,
              },
            },
          ],
        },
      },
    });

    if (!response) {
      throw new Error("Failed to add email to Notion");
    }

    return NextResponse.json({ success: true }, { status: 200 });
  } catch {
    return NextResponse.json({ success: false }, { status: 500 });
  }
}
