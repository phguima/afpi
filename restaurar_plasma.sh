#!/bin/bash

# ==============================================================================
# Script: restaurar_plasma.sh
# Missão: Recriar Layout Plasma com integração ao Discover
# Orquestrado por: Nexus & Conselho de Personas (Axis, Vinci)
# Local: projects/afpi/
# ==============================================================================

echo "🎨 Iniciando restauração do seu workspace Plasma..."

# --- 1. Instalação Manual Assistida (Garante atualizações via Discover) ---
instalar_da_store() {
    echo "📦 Abrindo o Discover para instalação dos widgets de terceiros..."
    echo "💡 Por favor, clique em 'Instalar' nas janelas que serão abertas."
    
    # Abre o Discover na página de busca
    plasma-discover --mode search --query "Panel Colorizer" &
    sleep 2
    plasma-discover --mode search --query "Modern Clock" &

    echo ""
    read -p "📌 Pressione [Enter] APÓS concluir as instalações no Discover para continuar com a montagem do layout..."
}

# --- 2. Geração do Layout via Console de Scripting do Plasma ---
aplicar_layout_plasma() {
    echo "🖥️  Construindo painéis e organizando widgets no desktop..."

    # Script JavaScript para o motor do Plasma (Kross/QJS)
    local plasma_js=$(cat <<EOF
// --- CONFIGURAÇÃO DOS PAINÉIS ---

// Painel Inferior (Principal - Baseado no ID 66)
var p1 = new Panel();
p1.location = "bottom";
p1.height = 44;
p1.alignment = "center";
p1.addWidget("org.kde.plasma.pager");
p1.addWidget("luisbocanegra.panel.colorizer");
p1.addWidget("org.kde.plasma.systemtray");

// Painel Superior/Flutuante (Atalhos - Baseado no ID 91)
var p2 = new Panel();
p2.location = "top";
p2.height = 52;
p2.floating = true;
p2.alignment = "center";
p2.addWidget("org.kde.plasma.kickerdash");
p2.addWidget("org.kde.plasma.icontasks");
p2.addWidget("luisbocanegra.panel.colorizer");

// --- CONFIGURAÇÃO DO DESKTOP (ID 1) ---
var d = desktopById(1);

// Adiciona o Relógio Moderno
d.addWidget("com.github.vKaras1337.modernclock");

// Adiciona as 4 instâncias de Monitores de Sistema
for (var i = 0; i < 4; i++) {
    d.addWidget("org.kde.plasma.systemmonitor");
}

print("Layout de containers e widgets criado com sucesso!");
EOF
)

    # Verifica se deve usar qdbus6 (Plasma 6) ou qdbus
    local dbus_cmd="qdbus6"
    if ! command -v qdbus6 &> /dev/null; then
        dbus_cmd="qdbus"
    fi

    # Invoca o console interativo do Plasma para executar o script acima
    $dbus_cmd org.kde.plasma-desktop /MainApplication loadScriptInInteractiveConsole "$plasma_js"
    
    echo "⚠️  Uma janela de 'Scripting Console' apareceu na sua tela."
    echo "👉 Clique no botão 'Executar' (ícone de Play) para aplicar o layout agora."
}

# --- Execução do Fluxo ---
instalar_da_store
aplicar_layout_plasma

echo "✅ Missão cumprida pelo Conselho!"
echo "📌 Dica: Após executar, você pode precisar ajustar a posição exata dos widgets de monitoramento no desktop."
