-- T10 (19/11/2026): índice em audit_events(actor_id).
-- Sem ele, excluir a conta (`delete_my_account`) varre a auditoria inteira duas
-- vezes: no `DELETE ... WHERE owner_id = ... OR actor_id = ...` e na conferência
-- da chave estrangeira `actor_id → auth.users` ao apagar o usuário. Com a
-- auditoria grande (homologação), a exclusão estourava o tempo do servidor.
-- Era a única chave estrangeira para auth.users sem índice. Migrations
-- anteriores não mudam.
BEGIN;

CREATE INDEX IF NOT EXISTS audit_events_actor_id_idx ON public.audit_events (actor_id);

COMMIT;
