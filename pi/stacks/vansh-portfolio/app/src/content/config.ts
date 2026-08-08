import { defineCollection, z } from "astro:content";

// Public-safe daily job-search summary. Only PUBLIC-SAFE content per
// vansh-talent-ops SYSTEM-PROMPT.md section 7 belongs here - no applications,
// contact details, visa status, salary negotiation, or review notes.
// Count fields are aggregate numbers only (how many, not which/where) -
// safe to publish, sourced from publisher.py's allowlist.
const jobSearch = defineCollection({
  type: "content",
  schema: z.object({
    date: z.string(),
    title: z.string(),
    summary: z.string(),
    jobsDiscovered: z.number().default(0),
    jobsVerified: z.number().default(0),
    jobsEligible: z.number().default(0),
  }),
});

export const collections = { "job-search": jobSearch };
