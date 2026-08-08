# vansh-portfolio

Public-safe portfolio site (Astro), fed only by approved exports from the
private `vansh-talent-ops` repository - never a direct copy of private data.

Publication is gated by an explicit `PUBLISH PORTFOLIO <id>` command and a
redaction manifest, defined in `vansh-talent-ops/SYSTEM-PROMPT.md` section 8.
Nothing here should ever contain: job applications, contact details, visa
status, salary negotiation notes, interview/rejection/offer history, or
company review summaries.

## Layout

- `src/content/job-search/` - one Markdown file per published day
  (`YYYY-MM-DD.md`), frontmatter: `date`, `title`, `summary`.
- `public/resumes/<job_id>/resume.pdf` - only for jobs explicitly approved
  for public display.

## Status

Scaffold only - dependencies not installed, not built or deployed yet.
Run `npm install && npm run dev` to preview locally.
