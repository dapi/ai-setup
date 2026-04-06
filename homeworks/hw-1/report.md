# Feature #001. Add Linter & Formatter - https://github.com/akoltun/ai-setup/issues/1

Time spent:
 - Brief: 4h
 - Spec: 2h
 - Plan: 1h
 - Implementation: 2h

Problems:
  - Изначально сгенерированный Brief включал множество деталей, 60% было удалено в ходе ревью, так как относилось к области spec-а
  - Ревью Брифа по сути зациклилось на добавлении и удалении наименований инструментов - Oxint и Oxfmt. Когда они есть в Брифе, замечание, что это детали реализации, и не нужны в Брифе. Когда их нет в Брифе, замечание, что не без указания конкретных инструментов, Acceptance Criteria будут раcплывчатыми - пришлось прервать
  - context7 содержит документации на устаревшую версию oxfmt
  - Ни один из ревью не обнаружил, что при использовании type-aware линтера нужно дополнительно установить oxlint-tsgolint

Quality:
 - Brief: более-менее
 - Spec: хорошо
 - Plan: очень хорошо
 - Implementation: хорошо

 # Feature #002. Add tests - https://github.com/akoltun/ai-setup/issues/2

Time spent:
 - Brief: 30m
 - Spec: 30m (Ревью прошел с первого раза. Уже сильно позже заметил, что ссылка была на спеку из первой фичи. Запустил ревью правильной спеки и все равно получил только одно неблокирующее замечание. Однако прямые ссылки в промптах - это боль)
 - Plan: 15m
 - Implementation: 1h

Problems:
  - Та же проблема, что и с первой фичей. Изначально сгенерированный Brief включал множество деталей реализации, которые были удалены в ходе ревью, так как относились к области spec-а

Quality:
 - Brief: хорошо
 - Spec: отлично
 - Plan: отлично
 - Implementation: хорошо

# Feature #003. Add CI/CD - https://github.com/akoltun/ai-setup/issues/3

Time spent:
 - Brief: 30m
 - Plan: 
 - Spec: 2h
 - Implementation: 

Problems:
  - Опять ревью Брифа зациклилось. То просит детализировать содержимое README, а затем просит убрать детализацию
  
Quality:
 - Brief: хорошо
 - Plan: 
 - Spec: хорошо
 - Implementation:

