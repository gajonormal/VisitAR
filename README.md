<p align="center">
  <img src="assets/app-icon.png" alt="VisitAR logo" width="150">
</p>

<h1 align="center">VisitAR</h1>
<p align="center">Aplicação de turismo interativo com visualização panorâmica 360º</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS">
</p>

## Sobre o projeto

O VisitAR é uma aplicação móvel de turismo interativo, desenvolvida como projeto de fim de curso e testada no Parque do Barrocal. Combina experiências imersivas em 360º com personalização de roteiros, gamificação baseada em geolocalização e um modo offline robusto — permitindo ao visitante explorar pontos de interesse de forma mais envolvente, através de fotografias panorâmicas que respondem aos movimentos do telemóvel (giroscópio).

O projeto foi inicialmente idealizado com foco em Realidade Aumentada (AR); o âmbito técnico foi depois reorientado a meio do desenvolvimento para visualização panorâmica 360º, acolhendo as recomendações da comissão avaliadora.

Projeto desenvolvido no âmbito da Licenciatura em Engenharia Informática (ESTCB/IPCB), sob orientação do Professor Doutor Pedro Silva.

## Funcionalidades

- **Visualização panorâmica 360º** com giroscópio
- **Geofencing** — deteção de proximidade a pontos de interesse via fórmula de Haversine, que dispara conteúdo multimédia relevante
- **Passaporte Digital** — sistema de gamificação baseado em geolocalização
- **Modo offline robusto** — pipeline de download sequencial, com total autonomia no terreno
- Personalização de roteiros
- Suporte multilingue (PT/EN)

## Stack técnica

- **Framework:** Flutter (Dart)
- **Backend:** Firebase
- **Navegação/Rotas:** OSRM (roteiros pedestres)
- **Plataformas:** Android, iOS, Web, Windows, macOS, Linux

## Como correr localmente

\`\`\`bash
git clone https://github.com/gajonormal/VisitAR.git
cd VisitAR
flutter pub get
flutter run
\`\`\`

## Equipa

Bernardo Maia, Leonardo Martins — sob orientação do Professor Doutor Pedro Silva
