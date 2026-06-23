# Brief: personal website for a Python backend developer

## Goal

Create a personal one-page website for a Python backend developer. The page should feel
beautiful, mysterious, technical, and slightly pixel-art inspired. It should work as a
portfolio/business card that can be shared with recruiters, clients, other developers, and
open-source collaborators.

The final result should communicate:

- this person is a backend/Python developer;
- the style is memorable, calm, and atmospheric;
- the visitor can quickly understand skills, work focus, and contact options;
- the site is polished enough to feel like a personal brand, not just a CV page.

## General mood

Keywords:

- mysterious;
- pixel art;
- terminal;
- backend systems;
- night city;
- dark interface;
- hacker atmosphere without looking aggressive;
- elegant developer portfolio;
- calm animation;
- minimal but expressive.

Suggested visual metaphor:

> A quiet backend engineer working behind the visible interface: APIs, databases,
> workers, queues, logs, and infrastructure glowing like hidden machinery in the dark.

## Target audience

- employers looking for a Python/backend developer;
- startup founders or product teams;
- technical leads;
- open-source collaborators;
- people who need a reliable backend engineer.

## Page structure

### 1. Hero section

Purpose: immediately show identity and atmosphere.

Content:

- name or nickname;
- role: "Python Backend Developer";
- short tagline;
- primary call to action: "Contact me";
- secondary call to action: "View GitHub" or "View projects".

Example copy:

```text
<Name / Nickname>
Python Backend Developer

I design backend systems, APIs, automation, and infrastructure for products that need
to be reliable, clear, and scalable.
```

Visual idea:

- dark background;
- pixel-art moon, server room, city skyline, or terminal window;
- subtle animated stars/noise/grid;
- blinking cursor near the role text;
- small pixel character or silhouette at a workstation.

### 2. About section

Purpose: explain who the developer is in human language.

Example copy:

```text
I am a backend developer focused on Python, APIs, databases, background jobs, and
developer tooling. I like building systems that are easy to maintain, easy to debug,
and calm under load.
```

Possible details to add later:

- location/time zone;
- years of experience;
- preferred industries;
- employment format: full-time, contract, freelance, open-source collaboration.

### 3. Skills section

Purpose: show technical fit quickly.

Suggested categories:

- Python: FastAPI, Django, Flask, asyncio;
- APIs: REST, WebSocket, OpenAPI;
- Databases: PostgreSQL, Redis, SQLite;
- Infrastructure: Docker, Linux, Nginx, CI/CD;
- Background processing: Celery, RQ, queues, schedulers;
- Testing: pytest, integration tests;
- Observability: logs, metrics, error tracking;
- Tools: Git, GitHub, GitLab, Bash.

Design:

- pixel cards;
- terminal-like tags;
- small animated icons;
- hover effect that looks like a terminal selection or scanline.

### 4. Projects section

Purpose: provide space for proof of work.

Each project card should include:

- project name;
- short description;
- tech stack;
- problem solved;
- GitHub/demo link if available.

Placeholder project card:

```text
API Platform
Backend service with authentication, PostgreSQL storage, background jobs, and
OpenAPI documentation.

Stack: Python, FastAPI, PostgreSQL, Redis, Docker
```

If there are no public projects yet, show this section as "Selected work" with private
project descriptions that do not reveal confidential information.

### 5. Services / work focus

Purpose: clarify what the developer can do.

Suggested cards:

- Backend API development;
- database design and optimization;
- automation scripts and bots;
- integrations with external services;
- Docker/Linux deployment;
- legacy backend cleanup;
- testing and reliability improvements.

### 6. Contact section

Purpose: make contact simple and visible.

Required contact methods:

- Telegram;
- Jabber/XMPP;
- email, if available;
- GitHub, if available;
- LinkedIn, if available.

Example layout:

```text
Telegram: @username
Jabber/XMPP: username@example.org
Email: name@example.com
GitHub: github.com/username
```

Important:

- do not hide all contacts behind animation;
- contacts must be copyable;
- include visible labels, not only icons;
- external links should open in a new tab.

## Visual style

### Color palette

Recommended:

- background: near-black / deep navy (`#080b12`, `#0d1020`);
- main text: soft white (`#e6edf3`);
- secondary text: muted blue-gray (`#8b9bb4`);
- accent 1: cyan (`#39d5ff`);
- accent 2: violet (`#8b5cf6`);
- accent 3: pixel green (`#7cff8a`) used carefully.

Avoid:

- too many neon colors;
- horror/gothic visuals;
- childish pixel art;
- overloaded cyberpunk effects.

### Typography

Recommended combination:

- headings: modern sans-serif or pixel-inspired display font;
- body: readable sans-serif;
- optional code/terminal text: monospace.

Examples:

- Inter + JetBrains Mono;
- Space Grotesk + IBM Plex Mono;
- Manrope + Fira Code.

### Pixel-art direction

Use pixel art as an accent, not as the whole interface.

Good uses:

- small hero illustration;
- pixel icons for stack items;
- 1px/2px borders;
- pixel grid background;
- low-frame animation;
- pixel cursor.

Avoid:

- making all text pixelated;
- reducing readability;
- too much retro-game UI.

## Animation requirements

Animations should be subtle and performant.

Suggested animations:

- blinking terminal cursor in hero title;
- slow moving star/noise background;
- pixel particles around the hero illustration;
- cards gently appear on scroll;
- hover states on skill/project cards;
- contact links glow slightly on hover.

Technical constraints:

- animations must respect `prefers-reduced-motion`;
- no heavy 3D or large video background;
- page should remain fast on mobile;
- use CSS animations where possible.

## Responsive behavior

The site must look good on:

- mobile: 360px and wider;
- tablet;
- desktop;
- wide screens.

Mobile priorities:

- clear role/title;
- readable text;
- contact buttons visible without searching;
- no horizontal scrolling;
- animations simplified.

## Recommended technical implementation

Suitable options:

1. Static site:
   - HTML, CSS, JavaScript;
   - easiest to deploy;
   - good for a one-page portfolio.

2. Modern frontend:
   - Astro or Next.js;
   - useful if projects/blog will be added later.

3. Design handoff first:
   - Figma mockup;
   - then implementation.

Recommended for this project:

> Astro or a simple static HTML/CSS site. The page is mostly visual and content-driven,
> so it does not need a complex backend.

## Deployment

Good deployment targets:

- GitHub Pages;
- Netlify;
- Vercel;
- Cloudflare Pages.

Basic requirements:

- custom domain support;
- HTTPS;
- fast load time;
- easy content updates.

## SEO and metadata

Add:

- page title: `<Name> - Python Backend Developer`;
- meta description;
- Open Graph image for sharing;
- favicon;
- structured social preview.

Example meta description:

```text
Personal website of <Name>, Python backend developer focused on APIs, databases,
automation, and reliable server-side systems.
```

## Accessibility requirements

- contrast must be readable;
- all links and buttons must be keyboard accessible;
- images must have useful alt text;
- animations must be optional via reduced-motion settings;
- contact information must be readable by screen readers.

## Content needed from the owner

Before final implementation, collect:

- name or nickname to display;
- preferred language: English, Russian, or both;
- Telegram username;
- Jabber/XMPP address;
- email, if public;
- GitHub profile;
- LinkedIn or other profile;
- 3-5 real projects or work examples;
- short personal bio;
- preferred employment/contact status;
- profile photo or decision to use only pixel-art avatar.

## Acceptance criteria

The site is ready when:

- it has a polished dark mysterious pixel-inspired visual style;
- the hero section clearly says "Python Backend Developer";
- all contact links are visible and copyable;
- the page works on mobile and desktop;
- animations are smooth and not distracting;
- performance is good;
- the site can be deployed to GitHub Pages, Vercel, Netlify, or Cloudflare Pages;
- the code is clean enough for another developer to maintain.

## Short version for a developer

Build a one-page personal website for a Python backend developer. Style: dark,
mysterious, elegant, with subtle pixel-art/terminal aesthetics. Sections: hero, about,
skills, projects, services/work focus, contact. Required contacts: Telegram and
Jabber/XMPP, with optional email/GitHub/LinkedIn. Add tasteful animations: blinking
cursor, subtle pixel particles, scroll reveals, card hover effects. Must be responsive,
accessible, fast, and easy to deploy as a static site.
