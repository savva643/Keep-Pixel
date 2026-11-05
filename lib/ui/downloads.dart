import 'package:flutter/material.dart';
import '../core/downloads.dart';
import 'shared.dart';

void showDownloads(BuildContext context, DownloadsController manager) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 720),
        builder: (_) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: ListenableBuilder(
                listenable: manager,
                builder: (context, _) =>
                    ListView(padding: const EdgeInsets.all(24), children: [
                      const Text('Загрузки',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                          'Установка продолжается при переходе между разделами.',
                          style: TextStyle(color: muted)),
                      const SizedBox(height: 24),
                      if (manager.jobs.isEmpty)
                        const StatePanel(
                            icon: Icons.download_outlined,
                            title: 'Загрузок пока нет',
                            description:
                                'Выбери игру в библиотеке и нажми «Установить».'),
                      ...manager.jobs.values.map((j) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                              child: Text(j.game.title,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          if (j.active)
                                            IconButton(
                                                tooltip: 'Отменить загрузку',
                                                onPressed: () =>
                                                    manager.cancel(j.game.id),
                                                icon: const Icon(Icons.close))
                                        ]),
                                        const SizedBox(height: 8),
                                        Text(j.label,
                                            style:
                                                const TextStyle(color: muted)),
                                        if (j.active) ...[
                                          const SizedBox(height: 12),
                                          LinearProgressIndicator(
                                              value: j.state ==
                                                      DownloadState.queued
                                                  ? null
                                                  : j.progress)
                                        ],
                                        if (j.error != null) ...[
                                          const SizedBox(height: 8),
                                          Text(j.error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error)),
                                          TextButton(
                                              onPressed: () =>
                                                  manager.enqueue(j.game),
                                              child: const Text('Повторить'))
                                        ]
                                      ]))))),
                    ]))));
