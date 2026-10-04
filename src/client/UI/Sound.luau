--!strict

-- Nombre anterior del gestor de audio. Todo el sonido vive en AudioManager; este módulo solo
-- existe para que el código que ya pedía `Sound` siga funcionando igual.

return require(script.Parent.AudioManager)
