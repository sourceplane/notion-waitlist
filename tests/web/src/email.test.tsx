import { render } from "@react-email/render";
import { afterEach, describe, expect, it, vi } from "vitest";

// apps/web/emails/index.tsx: the template's welcome email, rendered as the
// mail route renders it.
describe("the welcome email", () => {
  afterEach(() => {
    delete process.env.NEXT_PUBLIC_SITE_URL;
    vi.resetModules();
  });

  it("greets the visitor by name, with the logo from the site's own origin", async () => {
    process.env.NEXT_PUBLIC_SITE_URL = "https://waitlist.example.com";
    const { default: WelcomeTemplate } = await import("emails");
    const html = await render(WelcomeTemplate({ userFirstname: "Ada & Bob" }));
    expect(html).toContain("Hi <!-- -->Ada &amp; Bob<!-- -->,");
    expect(html).toContain('src="https://waitlist.example.com/waitlist-logo.png"');
    expect(html).toContain("Thanks for joining the waitlist");
    // Replies go to the sender the site sends from, not to the template's
    // author.
    expect(html).not.toContain("mailto:");
    expect(html).not.toContain("vercel.app");
  });
});
