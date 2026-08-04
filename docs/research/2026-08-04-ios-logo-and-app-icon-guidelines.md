# iOS logo and app-icon guidelines

Date: 2026-08-04

## Bottom line

Treat the brand logo and the iOS app icon as related but different assets. Create a distinctive, simple brand mark as vector artwork, then adapt its strongest recognisable element into a square, layered app icon. Do not squeeze the full wordmark or a collage of product features into the icon.

For current Apple-platform production, use Apple's latest App Icon Template and finish the artwork in Icon Composer. Keep an asset-catalog version only when the exact pre-Liquid-Glass appearance on older operating systems must be preserved. Apple states that an Icon Composer file replaces an existing `AppIcon` asset catalogue and Xcode generates compatible images for older releases; the asset-catalog route remains documented and supported.

For RideHorizon, the icon should communicate one primary idea at a glance — preferably the horizon/road journey — with audio awareness as a subtle secondary cue if it survives small-size testing. A motorbike, road, location pin, sound waves, horizon, initials and wordmark in one icon would be too much.

## Mandatory Apple and App Store requirements

These are submission, review or platform constraints, not merely aesthetic preferences.

- An App Store-distributed iOS app must include App Store icon imagery in its Xcode project. The current iOS/iPadOS layout is a square **1024 × 1024 px** canvas; the system applies the rounded-rectangle mask and automatically generates smaller sizes. Do not bake rounded corners into the supplied layers. [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) and [Xcode: Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon/)
- Use square, unmasked layers and keep important content centred so system masking does not crop it. If a background image is imported, it must be full bleed and opaque. [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- Supported app-icon colour spaces are sRGB, Gray Gamma 2.2 and Display P3; Display P3 support applies to iOS and iPadOS. [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- The icon and all App Store metadata must accurately represent the app. Icon imagery must be suitable for a 4+ audience, even when the app has a higher age rating. The developer must hold the rights to every included asset. Do not include irrelevant imagery from other mobile platforms. [App Review Guidelines 2.3.8–2.3.10](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- Do not copy or impersonate another app, use another developer's icon, brand or product name without approval, or use protected third-party material without permission. Do not create an icon confusingly similar to an Apple product or app, and do not reproduce Apple hardware in the app icon. [App Review Guidelines 4.1 and 5.2](https://developer.apple.com/app-store/review/guidelines/#copycats) and [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- Alternate app icons are also reviewed. Apple states that iOS and iPadOS alternate icons require their own dark, clear and tinted variants. [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- Changing the published App Store icon requires uploading and submitting a new app version for review. [App Store Connect Help: Add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon)

## Current Apple production model

### Preferred current route: layered Icon Composer file

Apple revised its app-icon guidance on 2026-06-08 for Liquid Glass. Its current iOS/iPadOS model is a layered 1024 × 1024 px design with default, dark, clear-light, clear-dark, tinted-light and tinted-dark appearances. Designers annotate default, dark and mono modes in Icon Composer; the system derives the clear and tinted results. Missing appearance variants can be generated automatically, so hand-authoring every appearance is not a submission requirement. [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons), [Icon Composer](https://developer.apple.com/icon-composer/) and [WWDC25: Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/)

Recommended workflow:

1. Start from Apple's latest App Icon Template rather than an old online mask or size chart. [Apple Design Resources](https://developer.apple.com/design/resources/)
2. Draw the source artwork in a vector editor, separating elements that need different depth, colour or appearance treatment. Export SVG where possible; use lossless PNG for unsupported SVG features, raster art or mesh gradients. Convert type to outlines. [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
3. Keep source layers flat and simple. Remove baked-in masks, backgrounds, blur, shadows, specular highlights and translucency that Icon Composer should apply and preview dynamically. [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) and [WWDC25: Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/)
4. Import the layers into Icon Composer, tune default, dark and mono appearances, and preview system lighting, backgrounds, platform masks and icon sizes. Apple's WWDC guidance allows up to four layer groups as a practical complexity bound. [WWDC25: Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/)
5. Add the `.icon` file to Xcode, select it as the target's app icon and test it in Simulator and on real devices in every supported appearance. [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)

Icon Composer is a finishing and delivery tool, not a complete logo-design environment. It expects artwork from a vector graphics editor. The standalone current release requires macOS Tahoe 26.4 or later. [Icon Composer](https://developer.apple.com/icon-composer/)

### Supported fallback: asset catalogue

Xcode can still generate the iOS/iPadOS sizes from one high-resolution image in an `AppIcon` asset set, or accept individually customised sizes. Use this route if the existing icon must look exactly the same on older supported operating systems; Apple warns that adding an Icon Composer file replaces the existing app-icon asset catalogue and generates a similar-looking legacy version rather than preserving it exactly. [Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon/) and [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)

## Apple design recommendations

These are Human Interface Guidelines, not binary upload requirements, but following them reduces recognition and rendering problems.

- **One memorable concept:** embrace simplicity and use a unique image that conveys the app's purpose and personality at a glance.
- **Clear silhouette and edges:** prefer clearly defined foreground edges; soft or feathered edges interfere with system highlights and shadows.
- **Designed for masking:** provide square, unmasked artwork, keep the subject optically centred and leave breathing room around the primary content.
- **Illustration over photography or UI:** photos contain too much detail for small sizes and appearance variants. Do not use an app screenshot or simply reproduce standard controls.
- **Minimal text:** the system already displays the app name. Icon text is hard to read, cannot be localised accessibly and adds clutter. A distinctive initial can work; explanatory words such as “Ride”, “Play”, “New” or a full `RideHorizon` wordmark should not be necessary.
- **Stable identity across appearances:** preserve the same core shapes in default, dark, clear and tinted modes. Adjust colour and contrast, not the identity itself.
- **Preview real conditions:** verify recognisability at Settings and notification sizes, against light and dark wallpapers, and in default, dark, clear and tinted appearances. Test on a physical iPhone as well as in previews.

Source for this section: [Apple HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons).

## Tool assessment

There is no single tool that should own the whole workflow. The strongest result comes from three distinct stages: concept exploration, editable vector construction, and Apple-specific rendering and delivery.

### Recommended for RideHorizon: Figma MCP plus a vector editor, then Apple tooling

Use the **Figma connector already available in Codex** as the collaborative source of truth. It can create and edit native Figma shapes, frames, styles and vector paths, so the design remains inspectable and editable rather than being trapped in a generated bitmap. Figma's current paid-plan agent can also generate multiple editable vector and logo directions directly on the canvas; Figma itself says generated marks should be treated as drafts and refined to become distinctive. Its image-vectorisation feature can turn a chosen raster concept into editable paths, although a simple mark should still be manually cleaned. [Figma: AI logo generator](https://www.figma.com/solutions/ai-logo-generator/), [Figma: AI vector generator](https://www.figma.com/solutions/ai-vector-generator/) and [Figma: Vectorize image](https://help.figma.com/hc/en-us/articles/38031452710807-Convert-static-images-to-vector-layers)

This is the best MCP route in the current workspace because it combines agent-driven iteration, native vector output, an editable shared canvas and Apple's official Figma app-icon template. The Figma MCP currently available to Codex has design-file read/write access. [Figma MCP](https://developers.figma.com/docs/figma-mcp-server/) and [Apple Design Resources](https://developer.apple.com/design/resources/)

For manual local refinement, install **Affinity** if a desktop vector editor is wanted. The current Affinity application combines professional vector, pixel and layout tools, is free, stores working files locally, and does not use local Affinity content to train Canva AI. It is the best-value local editor identified in this review. [Canva: Introducing the all-new Affinity](https://www.canva.com/newsroom/news/all-new-affinity/) and [Canva: Why Affinity is free](https://www.canva.com/newsroom/news/affinity-free/)

Finish Apple-platform appearances in **Icon Composer** after upgrading to macOS 26.4 or later. Until then, export a full-bleed opaque 1024 × 1024 RGB PNG from the vector master and continue using Xcode's supported asset-catalogue workflow. Icon Composer is the best iOS icon *packaging and appearance* tool, but it is not a logo generator or vector drawing application. [Icon Composer](https://developer.apple.com/icon-composer/) and [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)

### Other credible options

| Tool | Best use | Strength | Material limitation for RideHorizon |
|---|---|---|---|
| **Recraft paid** | Rapid AI exploration with direct SVG output | Generates editable SVG and supports logo/icon workflows | Free-plan work is public, owned by Recraft and not licensed for commercial use; no Recraft MCP is installed here. Use a paid plan only for production candidates. [Recraft vector generator](https://www.recraft.ai/ai-vector-generator) and [Recraft ownership](https://www.recraft.ai/docs/plans-and-billing/commercial-rights-and-ownership) |
| **Adobe Illustrator** | Highest-control professional vector production and AI-assisted exploration | Mature manual vector tools; Text to Vector produces editable graphics and Adobe describes it as commercially safe | Subscription cost and no installed local application or connector were found; excessive for this one mark unless the designer already uses Illustrator. [Adobe: Illustrator generative AI FAQ](https://helpx.adobe.com/illustrator/desktop/use-generative-ai/generative-ai-faq-illustrator.html) |
| **Affinity** | Free local vector construction and hand refinement | Professional-grade vectors, local files, no subscription | No Codex MCP is currently installed, so collaboration requires exported files or manual operation. |
| **Figma AI and Figma MCP** | Agent-assisted directions, comparison, refinement and vector master | Editable canvas, direct collaboration and Apple template support | AI agent requires a paid Figma plan; AI output still needs human distinctiveness, optical correction and legal screening. |
| **Canva MCP** | Fast moodboards, brand collateral and rough logo directions | A logo generator is callable from this Codex session and Canva is easy to operate | Template-led output is less suitable as the final unique master; use the more precise Figma or Affinity vector workflow for the mark itself. |
| **Codex image generation** | Fast visual concept exploration and edits | Already available and effective for exploring composition, colour and mood | Produces raster imagery rather than a clean, layered vector master. The RideHorizon concept generated in this task is 1254 × 1254 RGB PNG and should be redrawn, not merely shipped as the source artwork. |
| **Sketch** | Native Mac vector design with an offline option | Focused Mac editor; supports local documents and a perpetual Mac-only licence | Not installed and offers less agent integration here than Figma. [Sketch](https://www.sketch.com/) and [Sketch pricing](https://www.sketch.com/pricing/) |

### Local and connector state checked on 2026-08-04

- Installed: Xcode 26.3, `sips`, `iconutil` and `ffmpeg`.
- Not found locally: Icon Composer, Affinity, Adobe Illustrator, Sketch, Figma desktop, Inkscape or ImageMagick.
- Available within this Codex session: image generation, Figma read/write design tools and Canva design generation including logos.
- Current blocker to Apple's preferred finishing route: this Mac runs macOS 15.7.8, while the current standalone Icon Composer requires macOS 26.4 or later.

### Decision

Use **Figma MCP as the working design environment**, optionally use **Affinity for local hand refinement**, and keep **Xcode's asset catalogue for the next build**. Adopt Icon Composer only after the Mac is upgraded and the candidate has been validated as a strong flat mark first. Recraft paid is the best specialist alternative for generating many editable SVG concepts, but it does not improve the final decision, trademark screening or optical refinement, and it adds another paid service to the workflow.

## General professional logo practice

The following is a design recommendation and evidence-led synthesis, not an Apple rule.

1. **Make it distinctive before making it decorative.** WIPO describes distinctiveness — the ability to distinguish one business's goods or services from competitors — as a basic requirement for trademark protection. Avoid a generic combination that could belong to any motorcycle or navigation app. [WIPO: How to Protect a Trademark](https://www.wipo.int/en/web/trademarks/protection)
2. **Build a small identity system, not one overloaded file.** Maintain a primary wordmark, a standalone symbol, horizontal/stacked lock-ups and monochrome versions. The app icon should normally use the symbol, while the wordmark serves websites, launch materials and documents.
3. **Keep an editable vector master.** Define geometry, clear space, minimum sizes and a small colour palette. Export platform-specific derivatives from that master rather than repeatedly editing generated PNG files.
4. **Demand recognition without colour or detail.** Check the symbol in one colour, at small size and at a glance. Colour, gradients and Liquid Glass effects should reinforce an already recognisable form rather than rescue a weak silhouette.
5. **Test for category confusion and legal conflict before committing.** Search similar names and images in the UK IPO register and WIPO Global Brand Database, including related goods and services. WIPO recommends searching both global and national or regional registers because its database does not cover every record. This is screening, not legal clearance. [GOV.UK: Search for a trade mark](https://www.gov.uk/search-for-trademark), [WIPO: Search before filing](https://www.wipo.int/en/web/madrid-system/how_to/search/index) and [WIPO Global Brand Database](https://www.wipo.int/en/web/global-brand-database)
6. **Record usage rules.** Document the approved artwork, colours, clear space, minimum size, backgrounds and prohibited alterations so future marketing and product assets remain recognisably the same brand.

## RideHorizon acceptance checklist

A candidate should not be selected until it passes all of these checks:

- Recognisable as one idea at notification size without the app name.
- Clearly distinguishable from leading motorcycle navigation, mapping and audio-guide icons.
- No copied marks, unlicensed artwork, Apple hardware, other-platform imagery or implied Apple endorsement.
- Square 1024 × 1024 source; no pre-rounded corners; centred content; full-bleed opaque background.
- Editable vector source with logical layers suitable for Icon Composer.
- Core geometry remains the same across default, dark and mono treatments.
- Clear and legible in all six rendered appearances and on varied wallpapers.
- Tested in the current Xcode/Simulator and on the project's physical iPhone.
- UK IPO keyword and image search completed; WIPO search completed for intended markets and relevant classes.
- Separate wordmark and monochrome assets exist for non-app-icon uses.

## Sources and currency

All sources were accessed on 2026-08-04. Apple documentation is live and can change; recheck it immediately before App Store submission.

- Apple, **Human Interface Guidelines: App icons** — updated 2026-06-08: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple, **Creating your app icon using Icon Composer**: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
- Apple, **Configuring your app icon using an asset catalog**: https://developer.apple.com/documentation/xcode/configuring-your-app-icon/
- Apple, **Icon Composer**: https://developer.apple.com/icon-composer/
- Apple, **Apple Design Resources**: https://developer.apple.com/design/resources/
- Apple, **WWDC25: Create icons with Icon Composer**: https://developer.apple.com/videos/play/wwdc2025/361/
- Apple, **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- Apple, **App Store Connect Help: Add an app icon**: https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon
- WIPO, **How to Protect a Trademark**: https://www.wipo.int/en/web/trademarks/protection
- WIPO, **Search Before Filing an International Trademark Application**: https://www.wipo.int/en/web/madrid-system/how_to/search/index
- WIPO, **Global Brand Database**: https://www.wipo.int/en/web/global-brand-database
- UK Intellectual Property Office, **Search for a trade mark**: https://www.gov.uk/search-for-trademark
