import 'package:flutter/material.dart';

/// One of the platform capabilities shown in the "Intelligent Tools" section.
class PlatformCapability {
  const PlatformCapability({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

const List<PlatformCapability> kPlatformCapabilities = [
  PlatformCapability(
    title: 'Adaptive Scaling',
    description: 'Dynamic for your needs and grows with you.',
    icon: Icons.insights_rounded,
  ),
  PlatformCapability(
    title: 'Intelligent Insights',
    description: 'Data-driven insights for better decisions.',
    icon: Icons.lightbulb_outline_rounded,
  ),
  PlatformCapability(
    title: 'Seamless Integration',
    description: 'Works with your existing systems and tools.',
    icon: Icons.hub_rounded,
  ),
];

/// SkillDad's real leadership, as shown on the production website's landing
/// page (client/src/pages/LandingPage.jsx `staticDirectors`) and its photo
/// assets (client/public/assets/directors/). Used as the fallback in
/// [ContentService.fetchLandingDirectors] when the live
/// GET /api/public/directors call fails or returns nothing for the landing
/// page - exactly the same fallback strategy the website itself uses.
class Director {
  const Director({required this.name, required this.title, required this.imageAsset});

  final String name;
  final String title;
  final String imageAsset;
}

const List<Director> kDirectors = [
  Director(
    name: 'Prof. Dr. Anastas Angjeli',
    title: 'Honorary President',
    imageAsset: 'assets/images/directors/anastas.png',
  ),
  Director(
    name: 'Prof. Dr. Adrian Civici',
    title: 'Rector',
    imageAsset: 'assets/images/directors/adrian.png',
  ),
  Director(
    name: 'Prof. Dr. Ramiz Zekaj',
    title: 'President',
    imageAsset: 'assets/images/directors/ramiz.png',
  ),
  Director(
    name: 'Prof. Dr. Ismail Kocayusufoglu',
    title: 'Rector',
    imageAsset: 'assets/images/directors/ismail.png',
  ),
];
