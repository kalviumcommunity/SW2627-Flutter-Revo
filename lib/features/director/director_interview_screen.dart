import 'package:flutter/material.dart';

class DirectorInterviewScreen extends StatelessWidget {
  const DirectorInterviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Interview & Baseline Evidence'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // Header card
            Card(
              elevation: 2,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            'PRD Baseline Evidence & Interview Artifact',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified requirements from Director Sarah Jenkins & S130-Revo Team',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Operational KPI Targets
            Text(
              'Operational Impact Targets (Baseline Evidence)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildKpiCard(
              context: context,
              icon: Icons.timer,
              title: 'Coordination Time Reduction',
              metric: '≥ 30%',
              description: 'Target reduction in weekly schedule searching & correction time post-pilot.',
            ),
            _buildKpiCard(
              context: context,
              icon: Icons.notifications_active,
              title: 'Delayed Schedule Updates',
              metric: '≥ 50%',
              description: 'Target reduction in delayed schedule communications across simultaneous shows.',
            ),
            _buildKpiCard(
              context: context,
              icon: Icons.event_seat,
              title: 'Venue Double-Bookings',
              metric: '0 Conflicts',
              description: 'Zero confirmed venue conflicts in tested MVP scenarios.',
            ),
            _buildKpiCard(
              context: context,
              icon: Icons.group_off,
              title: 'Cast Rehearsal Overlaps',
              metric: '0 Overlaps',
              description: 'Zero confirmed cast member schedule overlaps in tested scenarios.',
            ),

            const SizedBox(height: 24),
            Text(
              'Director Interview Baseline Insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    _buildInterviewPoint(
                      'Q1: Core Coordination Pain Point',
                      'Managing 3+ concurrent productions through WhatsApp groups leads to missed calls, double-booked rehearsal spaces, and cast confusion.',
                    ),
                    const Divider(height: 24),
                    _buildInterviewPoint(
                      'Q2: Auditions & Casting (FR-03, FR-04, BR-06)',
                      'Directors need to define specific role slots per production, accept audition applications, and assign cast members with automatic role status tracking (Open -> Assigned).',
                    ),
                    const Divider(height: 24),
                    _buildInterviewPoint(
                      'Q3: Rehearsals & Conflict Detection (FR-05, FR-07, BR-01..05)',
                      'Pre-confirmation checks must block double-bookings immediately BEFORE writing to the database.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String metric,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(
                metric,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primaryContainer,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildInterviewPoint(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}
