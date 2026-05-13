part of 'trip_workspace_page.dart';

extension _TripWorkspaceBudgetSection on _TripWorkspacePageState {
  Widget _buildBudgetCard(ColorScheme cs) {
    if (_showBudgetAnalytics) {
      return _buildBudgetAnalyticsCard(cs);
    }

    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amountRub);

    final visible = _expenses
        .where((e) => _categoryFilter == 'all' || e.category == _categoryFilter)
        .toList();

    if (_sortMode == 'asc') {
      visible.sort((a, b) => a.amountRub.compareTo(b.amountRub));
    } else if (_sortMode == 'desc') {
      visible.sort((a, b) => b.amountRub.compareTo(a.amountRub));
    } else {
      visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Общая сумма: ${total.toStringAsFixed(2)} руб.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Geologica',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Аналитика расходов',
                onPressed: () {
                  setState(() {
                    _showBudgetAnalytics = true;
                  });
                },
                icon: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Сортировка',
                color: _TripWorkspacePageState._popupBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: _TripWorkspacePageState._popupBorder),
                ),
                onSelected: (value) {
                  setState(() {
                    _sortMode = value;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'none',
                    child: Text(
                      'Без сортировки',
                      style: TextStyle(
                        color: _TripWorkspacePageState._popupText,
                        fontFamily: 'Geologica',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'asc',
                    child: Text(
                      'По возрастанию',
                      style: TextStyle(
                        color: _TripWorkspacePageState._popupText,
                        fontFamily: 'Geologica',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'desc',
                    child: Text(
                      'По убыванию',
                      style: TextStyle(
                        color: _TripWorkspacePageState._popupText,
                        fontFamily: 'Geologica',
                      ),
                    ),
                  ),
                ],
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _TripWorkspacePageState._popupFieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _TripWorkspacePageState._popupBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoryFilter,
                      dropdownColor: _TripWorkspacePageState._popupBg,
                      iconEnabledColor: _TripWorkspacePageState._popupAccent,
                      style: const TextStyle(
                        color: _TripWorkspacePageState._popupText,
                        fontFamily: 'Geologica',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text(
                            'Все категории',
                            style: TextStyle(
                              color: _TripWorkspacePageState._popupText,
                              fontFamily: 'Geologica',
                            ),
                          ),
                        ),
                        ..._TripWorkspacePageState._categories.entries.map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                color: _TripWorkspacePageState._popupText,
                                fontFamily: 'Geologica',
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _categoryFilter = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _addingExpense ? null : _openAddExpenseDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD7E37A),
                foregroundColor: const Color(0xFF161616),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: _addingExpense
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Добавить расход'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _budgetLoading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет расходов',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final expense = visible[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _TripWorkspacePageState._categories[expense.category] ??
                                        expense.category,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${expense.amountRub.toStringAsFixed(2)} руб.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Редактировать',
                              onPressed: () => _openEditExpenseDialog(expense),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => _deleteExpense(expense),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAnalyticsCard(ColorScheme cs) {
    final totalsByCategory = <String, double>{};
    for (final expense in _expenses) {
      totalsByCategory[expense.category] =
          (totalsByCategory[expense.category] ?? 0) + expense.amountRub;
    }

    final items = totalsByCategory.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = items.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showBudgetAnalytics = false;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD7E37A),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Назад к расходам'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: _ExpensePieChart(
              values: {
                for (final item in items) item.key: item.value,
              },
              colors: _TripWorkspacePageState._categoryColors,
              total: total,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет данных для диаграммы',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final categoryKey = item.key;
                      final categoryLabel =
                          _TripWorkspacePageState._categories[categoryKey] ?? categoryKey;
                      final color =
                          _TripWorkspacePageState._categoryColors[categoryKey] ??
                              _TripWorkspacePageState._categoryColors['other']!;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                categoryLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${item.value.toStringAsFixed(2)} руб.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


