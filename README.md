# Tour of the Alps — iOS app

The companion app for the **Tour of the Alps**, a UCI ProSeries stage race across Tyrol, South Tyrol and Trentino. Built as part of the race's organizing team; launching with the **2027 edition**.

## The problem

During race week, fans, press and partners all need the same few things fast: today's stage, live results, who is riding, and race news, in three languages (English, Italian, German). Before this app that information was spread across the website, PDFs and social channels.

## What it does

- **Stages:** route, profile and details for every stage, with the current stage surfaced on Home.
- **Standings:** general and secondary classifications, updated during the race.
- **Teams & riders:** every team with its roster and a rider sheet.
- **News:** race news rendered from structured content blocks served by the API.
- **Push notifications:** topic-based (a global topic plus one per language), each opening the relevant screen through a deep link (`tota://stage/3`).
- **Sponsors:** partner placements managed from the backend, not hard-coded.
- **Offline-friendly:** a large shared image cache, so screens already visited still work with weak mountain coverage.

## Product decisions worth noting

- **Three iterations.** The app evolved from a 2025 version to a 2026 version to this rewrite, with a cleaner architecture (feature folders, a shared design system, config-driven API host).
- **Language follows the device**, falling back to English. Push topics follow the language too, and a device that changes language is moved between topics automatically.
- **Content lives in the backend.** News, sponsors and race data come from a REST API, so the organizing team can update the app during the race without a new release.
- **Deep links are keyed on what humans see** (the stage number), not internal database ids, which differ in real data and would silently open the wrong stage.

## Stack

SwiftUI · Swift Concurrency · Firebase Cloud Messaging · REST API (`/api/v1`) · String catalog localization (EN/IT/DE)

## Structure

```
App/            root view and app lifecycle
Core/           API client, config, routing, deep links, push
DesignSystem/   theme, typography, shared components
Features/       Home, Stages, Standings, Teams, News
Models/         API models
```
