import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'VisitAR'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Definições'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get general;

  /// No description provided for @managePermissions.
  ///
  /// In pt, this message translates to:
  /// **'Gerir Permissões'**
  String get managePermissions;

  /// No description provided for @openingSettings.
  ///
  /// In pt, this message translates to:
  /// **'A abrir definições...'**
  String get openingSettings;

  /// No description provided for @darkMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo Escuro'**
  String get darkMode;

  /// No description provided for @clearCache.
  ///
  /// In pt, this message translates to:
  /// **'Limpar Cache'**
  String get clearCache;

  /// No description provided for @cacheClearedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Cache limpa com sucesso!'**
  String get cacheClearedSuccess;

  /// No description provided for @account.
  ///
  /// In pt, this message translates to:
  /// **'Conta'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Conta'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarningTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Conta?'**
  String get deleteAccountWarningTitle;

  /// No description provided for @deleteAccountWarningBody.
  ///
  /// In pt, this message translates to:
  /// **'Esta ação é irreversível. Todos os teus dados serão apagados.'**
  String get deleteAccountWarningBody;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get delete;

  /// No description provided for @error.
  ///
  /// In pt, this message translates to:
  /// **'Erro'**
  String get error;

  /// No description provided for @version.
  ///
  /// In pt, this message translates to:
  /// **'Versão'**
  String get version;

  /// No description provided for @aboutThisPlace.
  ///
  /// In pt, this message translates to:
  /// **'Sobre este local'**
  String get aboutThisPlace;

  /// No description provided for @noDescription.
  ///
  /// In pt, this message translates to:
  /// **'Sem descrição.'**
  String get noDescription;

  /// No description provided for @readMore.
  ///
  /// In pt, this message translates to:
  /// **'Ler mais'**
  String get readMore;

  /// No description provided for @explore360.
  ///
  /// In pt, this message translates to:
  /// **'Explorar em 360º'**
  String get explore360;

  /// No description provided for @calculating.
  ///
  /// In pt, this message translates to:
  /// **'Calculando...'**
  String get calculating;

  /// No description provided for @addedToItinerary.
  ///
  /// In pt, this message translates to:
  /// **'Adicionado aos locais para o novo Roteiro!'**
  String get addedToItinerary;

  /// No description provided for @removedFromItinerary.
  ///
  /// In pt, this message translates to:
  /// **'Removido dos locais para o novo Roteiro.'**
  String get removedFromItinerary;

  /// No description provided for @loginRequiredTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sessão necessária'**
  String get loginRequiredTitle;

  /// No description provided for @loginRequiredBody1.
  ///
  /// In pt, this message translates to:
  /// **'Para '**
  String get loginRequiredBody1;

  /// No description provided for @loginRequiredBody2.
  ///
  /// In pt, this message translates to:
  /// **', precisas de ter uma conta e iniciar sessão.'**
  String get loginRequiredBody2;

  /// No description provided for @notNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get notNow;

  /// No description provided for @login.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar sessão'**
  String get login;

  /// No description provided for @actionSaveFavorites.
  ///
  /// In pt, this message translates to:
  /// **'guardar nos favoritos'**
  String get actionSaveFavorites;

  /// No description provided for @actionRegisterVisit.
  ///
  /// In pt, this message translates to:
  /// **'registar visitas no Passaporte'**
  String get actionRegisterVisit;

  /// No description provided for @alreadyVisited.
  ///
  /// In pt, this message translates to:
  /// **'Já visitaste este local!'**
  String get alreadyVisited;

  /// No description provided for @youAreAt.
  ///
  /// In pt, this message translates to:
  /// **'Estás a '**
  String get youAreAt;

  /// No description provided for @approachToRegister.
  ///
  /// In pt, this message translates to:
  /// **' deste local. Aproxima-te para registar a visita.'**
  String get approachToRegister;

  /// No description provided for @visitRegistered.
  ///
  /// In pt, this message translates to:
  /// **'✅ Visita registada no teu Passaporte!'**
  String get visitRegistered;

  /// No description provided for @congratsCompletedItinerary.
  ///
  /// In pt, this message translates to:
  /// **'🎉 Parabéns! Concluíste o roteiro'**
  String get congratsCompletedItinerary;

  /// No description provided for @achievementUnlocked.
  ///
  /// In pt, this message translates to:
  /// **'Conquista Desbloqueada!'**
  String get achievementUnlocked;

  /// No description provided for @fantastic.
  ///
  /// In pt, this message translates to:
  /// **'Fantástico!'**
  String get fantastic;

  /// No description provided for @noConnectionToDownload.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão para baixar.'**
  String get noConnectionToDownload;

  /// No description provided for @savedOffline.
  ///
  /// In pt, this message translates to:
  /// **'Guardado offline'**
  String get savedOffline;

  /// No description provided for @errorDownloading.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao baixar.'**
  String get errorDownloading;

  /// No description provided for @contentRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo removido.'**
  String get contentRemoved;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @arMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo AR'**
  String get arMode;

  /// No description provided for @view360.
  ///
  /// In pt, this message translates to:
  /// **'Ver 360º'**
  String get view360;

  /// No description provided for @navigate.
  ///
  /// In pt, this message translates to:
  /// **'Navegar'**
  String get navigate;

  /// No description provided for @time.
  ///
  /// In pt, this message translates to:
  /// **'Tempo'**
  String get time;

  /// No description provided for @distance.
  ///
  /// In pt, this message translates to:
  /// **'Distância'**
  String get distance;

  /// No description provided for @pause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In pt, this message translates to:
  /// **'Parar'**
  String get stop;

  /// No description provided for @stopNavigation.
  ///
  /// In pt, this message translates to:
  /// **'Parar Navegação'**
  String get stopNavigation;

  /// No description provided for @stopNavigationConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Queres parar de seguir as indicações deste roteiro?'**
  String get stopNavigationConfirm;

  /// No description provided for @finish.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get finish;

  /// No description provided for @searchLocation.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar local...'**
  String get searchLocation;

  /// No description provided for @noLocationFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local encontrado'**
  String get noLocationFound;

  /// No description provided for @nearbyPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Locais Próximos'**
  String get nearbyPlaces;

  /// No description provided for @tabExplore.
  ///
  /// In pt, this message translates to:
  /// **'Explorar'**
  String get tabExplore;

  /// No description provided for @tabMap.
  ///
  /// In pt, this message translates to:
  /// **'Mapa'**
  String get tabMap;

  /// No description provided for @tabItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Roteiros'**
  String get tabItineraries;

  /// No description provided for @tabFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Favoritos'**
  String get tabFavorites;

  /// No description provided for @tabProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get tabProfile;

  /// No description provided for @errorUpdatingFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao atualizar favoritos.'**
  String get errorUpdatingFavorites;

  /// No description provided for @approx.
  ///
  /// In pt, this message translates to:
  /// **'Aprox.'**
  String get approx;

  /// No description provided for @viewDetails.
  ///
  /// In pt, this message translates to:
  /// **'Ver Detalhes'**
  String get viewDetails;

  /// No description provided for @welcomeExplorer.
  ///
  /// In pt, this message translates to:
  /// **'Explorador'**
  String get welcomeExplorer;

  /// No description provided for @welcomeHeader.
  ///
  /// In pt, this message translates to:
  /// **'BEM-VINDO/A'**
  String get welcomeHeader;

  /// No description provided for @hello.
  ///
  /// In pt, this message translates to:
  /// **'Olá, '**
  String get hello;

  /// No description provided for @arBannerTitle.
  ///
  /// In pt, this message translates to:
  /// **'O património\nvive à tua frente.'**
  String get arBannerTitle;

  /// No description provided for @arBannerSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Aponta a câmara e descobre.'**
  String get arBannerSubtitle;

  /// No description provided for @vistas360.
  ///
  /// In pt, this message translates to:
  /// **'Vistas 360º'**
  String get vistas360;

  /// No description provided for @vistas360Title.
  ///
  /// In pt, this message translates to:
  /// **'Explora os pontos de interesse'**
  String get vistas360Title;

  /// No description provided for @vistas360Subtitle.
  ///
  /// In pt, this message translates to:
  /// **'Descobre vistas imersivas a 360 graus.'**
  String get vistas360Subtitle;

  /// No description provided for @nearYou.
  ///
  /// In pt, this message translates to:
  /// **'Perto de ti'**
  String get nearYou;

  /// No description provided for @results.
  ///
  /// In pt, this message translates to:
  /// **'resultados'**
  String get results;

  /// No description provided for @result.
  ///
  /// In pt, this message translates to:
  /// **'resultado'**
  String get result;

  /// No description provided for @locationNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Localização não encontrada'**
  String get locationNotFound;

  /// No description provided for @noPlacesNearYou.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local perto de ti (50km)'**
  String get noPlacesNearYou;

  /// No description provided for @turnOnGps.
  ///
  /// In pt, this message translates to:
  /// **'Ativa o GPS ou aguarda um momento'**
  String get turnOnGps;

  /// No description provided for @tryExploringOtherZones.
  ///
  /// In pt, this message translates to:
  /// **'Experimenta explorar noutras zonas do mapa'**
  String get tryExploringOtherZones;

  /// No description provided for @suggestedItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Roteiros Sugeridos'**
  String get suggestedItineraries;

  /// No description provided for @viewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get viewAll;

  /// No description provided for @noItinerariesAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum roteiro disponível no momento.'**
  String get noItinerariesAvailable;

  /// No description provided for @noPersonalItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não criaste roteiros. Explora o mapa!'**
  String get noPersonalItineraries;

  /// No description provided for @logout.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get logout;

  /// No description provided for @editProfile.
  ///
  /// In pt, this message translates to:
  /// **'Editar Perfil'**
  String get editProfile;

  /// No description provided for @myItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Os meus roteiros'**
  String get myItineraries;

  /// No description provided for @myPassport.
  ///
  /// In pt, this message translates to:
  /// **'O meu Passaporte'**
  String get myPassport;

  /// No description provided for @myFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Os meus favoritos'**
  String get myFavorites;

  /// No description provided for @offlineDownloads.
  ///
  /// In pt, this message translates to:
  /// **'Downloads Offline'**
  String get offlineDownloads;

  /// No description provided for @adminPanel.
  ///
  /// In pt, this message translates to:
  /// **'Painel de Admin'**
  String get adminPanel;

  /// No description provided for @createBadgesAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Criar Badges (Admin)'**
  String get createBadgesAdmin;

  /// No description provided for @resetAchievementsTest.
  ///
  /// In pt, this message translates to:
  /// **'Reset Conquistas (Teste)'**
  String get resetAchievementsTest;

  /// No description provided for @resetStampsTest.
  ///
  /// In pt, this message translates to:
  /// **'Reset Carimbos (Teste)'**
  String get resetStampsTest;

  /// No description provided for @latestAchievements.
  ///
  /// In pt, this message translates to:
  /// **'Últimas Conquistas'**
  String get latestAchievements;

  /// No description provided for @guest.
  ///
  /// In pt, this message translates to:
  /// **'Visitante'**
  String get guest;

  /// No description provided for @guestMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo sem conta'**
  String get guestMode;

  /// No description provided for @guestLimitedAccess.
  ///
  /// In pt, this message translates to:
  /// **'Como visitante, tens acesso limitado. Cria uma conta para mais funcionalidades!'**
  String get guestLimitedAccess;

  /// No description provided for @chooseLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Escolher Idioma'**
  String get chooseLanguage;

  /// No description provided for @languageChangedTo.
  ///
  /// In pt, this message translates to:
  /// **'Idioma alterado para'**
  String get languageChangedTo;

  /// No description provided for @local.
  ///
  /// In pt, this message translates to:
  /// **'(local)'**
  String get local;

  /// No description provided for @loginRegister.
  ///
  /// In pt, this message translates to:
  /// **'Login/Registo'**
  String get loginRegister;

  /// No description provided for @badgesCreated.
  ///
  /// In pt, this message translates to:
  /// **'✅ Badges criadas no Firestore!'**
  String get badgesCreated;

  /// No description provided for @achievementsDeleted.
  ///
  /// In pt, this message translates to:
  /// **'🗑️ Todas as tuas conquistas foram apagadas!'**
  String get achievementsDeleted;

  /// No description provided for @stampsDeleted.
  ///
  /// In pt, this message translates to:
  /// **'🗑️ Todos os teus carimbos de visitas foram apagados!'**
  String get stampsDeleted;

  /// No description provided for @searchItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar roteiros...'**
  String get searchItineraries;

  /// No description provided for @suggested.
  ///
  /// In pt, this message translates to:
  /// **'Sugeridos'**
  String get suggested;

  /// No description provided for @mine.
  ///
  /// In pt, this message translates to:
  /// **'Meus'**
  String get mine;

  /// No description provided for @completed.
  ///
  /// In pt, this message translates to:
  /// **'Concluídos'**
  String get completed;

  /// No description provided for @noItineraryFoundFor.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum roteiro encontrado para'**
  String get noItineraryFoundFor;

  /// No description provided for @loginToCreateItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Inicia sessão para criares e veres os teus roteiros.'**
  String get loginToCreateItineraries;

  /// No description provided for @stillNoItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Ainda sem roteiros'**
  String get stillNoItineraries;

  /// No description provided for @clickPlusToCreate.
  ///
  /// In pt, this message translates to:
  /// **'Clica no botão + para criar o teu primeiro roteiro.'**
  String get clickPlusToCreate;

  /// No description provided for @loginToViewCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Inicia sessão para veres os roteiros que já concluíste.'**
  String get loginToViewCompleted;

  /// No description provided for @noCompletedItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum roteiro concluído'**
  String get noCompletedItineraries;

  /// No description provided for @completedWillAppearHere.
  ///
  /// In pt, this message translates to:
  /// **'Quando completares um roteiro, aparece aqui.'**
  String get completedWillAppearHere;

  /// No description provided for @noAvailableItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum roteiro disponível'**
  String get noAvailableItineraries;

  /// No description provided for @noSuggestedItinerariesAtMoment.
  ///
  /// In pt, this message translates to:
  /// **'De momento não há roteiros sugeridos.'**
  String get noSuggestedItinerariesAtMoment;

  /// No description provided for @loginToViewFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Inicia sessão para guardares e veres os teus favoritos.'**
  String get loginToViewFavorites;

  /// No description provided for @locationsPois.
  ///
  /// In pt, this message translates to:
  /// **'Locais (POIs)'**
  String get locationsPois;

  /// No description provided for @searchFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar nos favoritos...'**
  String get searchFavorites;

  /// No description provided for @noFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Sem favoritos'**
  String get noFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Removido dos favoritos'**
  String get removedFromFavorites;

  /// No description provided for @errorLoadingFavoriteItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar roteiros favoritos.'**
  String get errorLoadingFavoriteItineraries;

  /// No description provided for @noFavoriteItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Sem roteiros favoritos'**
  String get noFavoriteItineraries;

  /// No description provided for @stops.
  ///
  /// In pt, this message translates to:
  /// **'Paragens'**
  String get stops;

  /// No description provided for @removeFavoriteQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Remover Favorito?'**
  String get removeFavoriteQuestion;

  /// No description provided for @doYouWantToRemove.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover'**
  String get doYouWantToRemove;

  /// No description provided for @fromFavorites.
  ///
  /// In pt, this message translates to:
  /// **'dos favoritos?'**
  String get fromFavorites;

  /// No description provided for @remove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get remove;

  /// No description provided for @errorRemovingFavorite.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao remover dos favoritos.'**
  String get errorRemovingFavorite;

  /// No description provided for @errorLoadingFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar favoritos.'**
  String get errorLoadingFavorites;

  /// No description provided for @name.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get name;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In pt, this message translates to:
  /// **'O nome não pode ser vazio'**
  String get nameCannotBeEmpty;

  /// No description provided for @email.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @gender.
  ///
  /// In pt, this message translates to:
  /// **'Género'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In pt, this message translates to:
  /// **'Masculino'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In pt, this message translates to:
  /// **'Feminino'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get genderOther;

  /// No description provided for @genderPreferNotToSay.
  ///
  /// In pt, this message translates to:
  /// **'Prefiro não dizer'**
  String get genderPreferNotToSay;

  /// No description provided for @nationality.
  ///
  /// In pt, this message translates to:
  /// **'Nacionalidade'**
  String get nationality;

  /// No description provided for @changePassword.
  ///
  /// In pt, this message translates to:
  /// **'Alterar Palavra-passe'**
  String get changePassword;

  /// No description provided for @newPassword.
  ///
  /// In pt, this message translates to:
  /// **'Nova password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar nova password'**
  String get confirmNewPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In pt, this message translates to:
  /// **'Não coincidem'**
  String get passwordsDoNotMatch;

  /// No description provided for @saveChanges.
  ///
  /// In pt, this message translates to:
  /// **'Guardar Alterações'**
  String get saveChanges;

  /// No description provided for @reauthRequired.
  ///
  /// In pt, this message translates to:
  /// **'Atenção: Password requer re-autenticação.'**
  String get reauthRequired;

  /// No description provided for @poisAdded.
  ///
  /// In pt, this message translates to:
  /// **'Pontos de interesse adicionados'**
  String get poisAdded;

  /// No description provided for @cannotLoadStops.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar as paragens.'**
  String get cannotLoadStops;

  /// No description provided for @startRoteiro.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar Roteiro'**
  String get startRoteiro;

  /// No description provided for @errorLoadingItinerary.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar roteiro'**
  String get errorLoadingItinerary;

  /// No description provided for @profileUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Perfil atualizado!'**
  String get profileUpdated;

  /// No description provided for @locationError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível obter a tua localização.'**
  String get locationError;

  /// No description provided for @registerVisitError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao registar visita.'**
  String get registerVisitError;

  /// No description provided for @error360.
  ///
  /// In pt, this message translates to:
  /// **'Erro 360:'**
  String get error360;

  /// No description provided for @no3dModel.
  ///
  /// In pt, this message translates to:
  /// **'Sem modelo 3D'**
  String get no3dModel;

  /// No description provided for @view3dModel.
  ///
  /// In pt, this message translates to:
  /// **'Visualizar Modelo 3D'**
  String get view3dModel;

  /// No description provided for @navigateToLocation.
  ///
  /// In pt, this message translates to:
  /// **'Navegar para o Local'**
  String get navigateToLocation;

  /// No description provided for @listenAudioGuide.
  ///
  /// In pt, this message translates to:
  /// **'Ouvir áudio guia'**
  String get listenAudioGuide;

  /// No description provided for @descriptionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get descriptionLabel;

  /// No description provided for @destination.
  ///
  /// In pt, this message translates to:
  /// **'Destino:'**
  String get destination;

  /// No description provided for @loadingMap.
  ///
  /// In pt, this message translates to:
  /// **'A carregar mapa...'**
  String get loadingMap;

  /// No description provided for @yourLocation.
  ///
  /// In pt, this message translates to:
  /// **'A tua localização'**
  String get yourLocation;

  /// No description provided for @errorLoadingMap.
  ///
  /// In pt, this message translates to:
  /// **'Ocorreu um erro a carregar o mapa'**
  String get errorLoadingMap;

  /// No description provided for @showAll.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar: Todos'**
  String get showAll;

  /// No description provided for @onlyFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Apenas favoritos'**
  String get onlyFavorites;

  /// No description provided for @searchRadius.
  ///
  /// In pt, this message translates to:
  /// **'Raio de busca:'**
  String get searchRadius;

  /// No description provided for @filterByCategory.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar por Categoria'**
  String get filterByCategory;

  /// No description provided for @sessionRequired.
  ///
  /// In pt, this message translates to:
  /// **'Sessão necessária'**
  String get sessionRequired;

  /// No description provided for @exploreLocationsPois.
  ///
  /// In pt, this message translates to:
  /// **'Explorar Local (POIs)'**
  String get exploreLocationsPois;

  /// No description provided for @profileUpdateSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Perfil atualizado com sucesso'**
  String get profileUpdateSuccess;

  /// No description provided for @profileUpdateError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao atualizar perfil'**
  String get profileUpdateError;

  /// No description provided for @addedToFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Adicionado aos favoritos'**
  String get addedToFavorites;

  /// No description provided for @errorUpdatingFavorite.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao atualizar favorito'**
  String get errorUpdatingFavorite;

  /// No description provided for @roteiroAvailableOffline.
  ///
  /// In pt, this message translates to:
  /// **'Roteiro já está disponível offline.'**
  String get roteiroAvailableOffline;

  /// No description provided for @downloadSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Download concluído com sucesso!'**
  String get downloadSuccess;

  /// No description provided for @downloadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao transferir roteiro.'**
  String get downloadError;

  /// No description provided for @deleteRoteiro.
  ///
  /// In pt, this message translates to:
  /// **'Apagar Roteiro'**
  String get deleteRoteiro;

  /// No description provided for @deleteRoteiroConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Tens a certeza que queres apagar este roteiro? Esta ação é irreversível.'**
  String get deleteRoteiroConfirm;

  /// No description provided for @roteiroDeletedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Roteiro apagado com sucesso!'**
  String get roteiroDeletedSuccess;

  /// No description provided for @errorDeletingRoteiro.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao apagar roteiro.'**
  String get errorDeletingRoteiro;

  /// No description provided for @category.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get category;

  /// No description provided for @duration.
  ///
  /// In pt, this message translates to:
  /// **'Duração'**
  String get duration;

  /// No description provided for @explorationProgress.
  ///
  /// In pt, this message translates to:
  /// **'Progresso da Exploração'**
  String get explorationProgress;

  /// No description provided for @placesVisited.
  ///
  /// In pt, this message translates to:
  /// **'locais visitados'**
  String get placesVisited;

  /// No description provided for @roteiroCompletedBadge.
  ///
  /// In pt, this message translates to:
  /// **'Roteiro Concluído! Badge ganho.'**
  String get roteiroCompletedBadge;

  /// No description provided for @languageChanged.
  ///
  /// In pt, this message translates to:
  /// **'Idioma alterado para {lang}'**
  String languageChanged(String lang);

  /// No description provided for @languageChangedLocal.
  ///
  /// In pt, this message translates to:
  /// **'Idioma alterado para {lang} (local)'**
  String languageChangedLocal(String lang);

  /// No description provided for @opening.
  ///
  /// In pt, this message translates to:
  /// **'A abrir...'**
  String get opening;

  /// No description provided for @searchDownloads.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar nos downloads...'**
  String get searchDownloads;

  /// No description provided for @noDownloadsOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem downloads offline'**
  String get noDownloadsOffline;

  /// No description provided for @noLocationFoundFor.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local encontrado para \'{query}\''**
  String noLocationFoundFor(String query);

  /// No description provided for @availableOffline.
  ///
  /// In pt, this message translates to:
  /// **'Disponível offline'**
  String get availableOffline;

  /// No description provided for @noRoteirosOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem roteiros offline'**
  String get noRoteirosOffline;

  /// No description provided for @noRoteiroFoundFor.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum roteiro encontrado para \'{query}\''**
  String noRoteiroFoundFor(String query);

  /// No description provided for @offlineStops.
  ///
  /// In pt, this message translates to:
  /// **'{count} paragens • Offline'**
  String offlineStops(int count);

  /// No description provided for @deleteDownloadTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar Download?'**
  String get deleteDownloadTitle;

  /// No description provided for @deleteDownloadConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover \'{name}\' dos downloads?'**
  String deleteDownloadConfirm(String name);

  /// No description provided for @deleteButton.
  ///
  /// In pt, this message translates to:
  /// **'Apagar'**
  String get deleteButton;

  /// No description provided for @poiRemoved.
  ///
  /// In pt, this message translates to:
  /// **'{name} removido.'**
  String poiRemoved(String name);

  /// No description provided for @errorRemoving.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao remover.'**
  String get errorRemoving;

  /// No description provided for @roteiroRemoved.
  ///
  /// In pt, this message translates to:
  /// **'{title} removido.'**
  String roteiroRemoved(String title);

  /// No description provided for @errorRemovingRoteiro.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao remover roteiro.'**
  String get errorRemovingRoteiro;

  /// No description provided for @roteiroUpdatedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Roteiro atualizado com sucesso!'**
  String get roteiroUpdatedSuccess;

  /// No description provided for @roteiroCreatedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Roteiro criado com sucesso!'**
  String get roteiroCreatedSuccess;

  /// No description provided for @errorCreatingRoteiro.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao criar roteiro. Tens a sessão iniciada?'**
  String get errorCreatingRoteiro;

  /// No description provided for @filters.
  ///
  /// In pt, this message translates to:
  /// **'Filtros'**
  String get filters;

  /// No description provided for @clear.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get clear;

  /// No description provided for @applyFilters.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar Filtros'**
  String get applyFilters;

  /// No description provided for @onlyWith3d.
  ///
  /// In pt, this message translates to:
  /// **'Apenas com Modelo 3D'**
  String get onlyWith3d;

  /// No description provided for @onlyWith360.
  ///
  /// In pt, this message translates to:
  /// **'Apenas com 360'**
  String get onlyWith360;

  /// No description provided for @difficulty.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade'**
  String get difficulty;

  /// No description provided for @catAll.
  ///
  /// In pt, this message translates to:
  /// **'Tudo'**
  String get catAll;

  /// No description provided for @catHistoric.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get catHistoric;

  /// No description provided for @catNature.
  ///
  /// In pt, this message translates to:
  /// **'Natureza'**
  String get catNature;

  /// No description provided for @catGeologic.
  ///
  /// In pt, this message translates to:
  /// **'Geológico'**
  String get catGeologic;

  /// No description provided for @catTrail.
  ///
  /// In pt, this message translates to:
  /// **'Trilho'**
  String get catTrail;

  /// No description provided for @catGastronomy.
  ///
  /// In pt, this message translates to:
  /// **'Gastronomia'**
  String get catGastronomy;

  /// No description provided for @difAny.
  ///
  /// In pt, this message translates to:
  /// **'Qualquer'**
  String get difAny;

  /// No description provided for @difEasy.
  ///
  /// In pt, this message translates to:
  /// **'Fácil'**
  String get difEasy;

  /// No description provided for @difMedium.
  ///
  /// In pt, this message translates to:
  /// **'Moderado'**
  String get difMedium;

  /// No description provided for @difHard.
  ///
  /// In pt, this message translates to:
  /// **'Difícil'**
  String get difHard;

  /// No description provided for @badgeCatExploration.
  ///
  /// In pt, this message translates to:
  /// **'Exploração'**
  String get badgeCatExploration;

  /// No description provided for @badgeCatItineraries.
  ///
  /// In pt, this message translates to:
  /// **'Roteiros'**
  String get badgeCatItineraries;

  /// No description provided for @badgeCatCreation.
  ///
  /// In pt, this message translates to:
  /// **'Criação'**
  String get badgeCatCreation;

  /// No description provided for @badgePrimeiroCarimboTitle.
  ///
  /// In pt, this message translates to:
  /// **'Primeiro Carimbo'**
  String get badgePrimeiroCarimboTitle;

  /// No description provided for @badgePrimeiroCarimboDesc.
  ///
  /// In pt, this message translates to:
  /// **'Visitaste o teu primeiro ponto de interesse!'**
  String get badgePrimeiroCarimboDesc;

  /// No description provided for @badgeConhecedorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conhecedor'**
  String get badgeConhecedorTitle;

  /// No description provided for @badgeConhecedorDesc.
  ///
  /// In pt, this message translates to:
  /// **'Visitaste 5 pontos de interesse.'**
  String get badgeConhecedorDesc;

  /// No description provided for @badgeColecionadorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Colecionador'**
  String get badgeColecionadorTitle;

  /// No description provided for @badgeColecionadorDesc.
  ///
  /// In pt, this message translates to:
  /// **'Visitaste 10 pontos de interesse.'**
  String get badgeColecionadorDesc;

  /// No description provided for @badgeGrandeExploradorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Grande Explorador'**
  String get badgeGrandeExploradorTitle;

  /// No description provided for @badgeGrandeExploradorDesc.
  ///
  /// In pt, this message translates to:
  /// **'Visitaste 25 pontos de interesse.'**
  String get badgeGrandeExploradorDesc;

  /// No description provided for @badgePrimeiroRoteiroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Primeiro Roteiro'**
  String get badgePrimeiroRoteiroTitle;

  /// No description provided for @badgePrimeiroRoteiroDesc.
  ///
  /// In pt, this message translates to:
  /// **'Completaste o teu primeiro roteiro!'**
  String get badgePrimeiroRoteiroDesc;

  /// No description provided for @badgeAventureiroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Aventureiro'**
  String get badgeAventureiroTitle;

  /// No description provided for @badgeAventureiroDesc.
  ///
  /// In pt, this message translates to:
  /// **'Completaste 3 roteiros.'**
  String get badgeAventureiroDesc;

  /// No description provided for @badgeViajanteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Viajante'**
  String get badgeViajanteTitle;

  /// No description provided for @badgeViajanteDesc.
  ///
  /// In pt, this message translates to:
  /// **'Completaste 5 roteiros.'**
  String get badgeViajanteDesc;

  /// No description provided for @badgeCriadorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criador'**
  String get badgeCriadorTitle;

  /// No description provided for @badgeCriadorDesc.
  ///
  /// In pt, this message translates to:
  /// **'Criaste o teu primeiro roteiro!'**
  String get badgeCriadorDesc;

  /// No description provided for @badgeGuiaLocalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Guia Local'**
  String get badgeGuiaLocalTitle;

  /// No description provided for @badgeGuiaLocalDesc.
  ///
  /// In pt, this message translates to:
  /// **'Criaste 3 roteiros.'**
  String get badgeGuiaLocalDesc;

  /// No description provided for @stampsTab.
  ///
  /// In pt, this message translates to:
  /// **'Carimbos'**
  String get stampsTab;

  /// No description provided for @achievementsTab.
  ///
  /// In pt, this message translates to:
  /// **'Conquistas'**
  String get achievementsTab;

  /// No description provided for @noStampsYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda sem carimbos'**
  String get noStampsYet;

  /// No description provided for @noStampsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Visita pontos de interesse para\ncolecionar carimbos no teu passaporte!'**
  String get noStampsSubtitle;

  /// No description provided for @placesVisitedSingular.
  ///
  /// In pt, this message translates to:
  /// **'local visitado'**
  String get placesVisitedSingular;

  /// No description provided for @continueExploring.
  ///
  /// In pt, this message translates to:
  /// **'Continua a explorar!'**
  String get continueExploring;

  /// No description provided for @noAchievementsDefined.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conquista definida no servidor ainda.'**
  String get noAchievementsDefined;

  /// No description provided for @achievementsProgress.
  ///
  /// In pt, this message translates to:
  /// **'{earned} de {total} conquistas'**
  String achievementsProgress(int earned, int total);

  /// No description provided for @visitedProgress.
  ///
  /// In pt, this message translates to:
  /// **'{visited} de {total} locais visitados'**
  String visitedProgress(int visited, int total);

  /// No description provided for @actionSaveItineraries.
  ///
  /// In pt, this message translates to:
  /// **'guardar roteiros nos favoritos'**
  String get actionSaveItineraries;

  /// No description provided for @adminNewPoi.
  ///
  /// In pt, this message translates to:
  /// **'Novo Ponto de Interesse'**
  String get adminNewPoi;

  /// No description provided for @adminPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Fotos (Obrigatório)'**
  String get adminPhotos;

  /// No description provided for @adminAddFromGallery.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar da Galeria'**
  String get adminAddFromGallery;

  /// No description provided for @adminRequired.
  ///
  /// In pt, this message translates to:
  /// **'Obrigatório'**
  String get adminRequired;

  /// No description provided for @adminInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Inválido'**
  String get adminInvalid;

  /// No description provided for @adminLocalName.
  ///
  /// In pt, this message translates to:
  /// **'Nome do Local'**
  String get adminLocalName;

  /// No description provided for @adminDescPt.
  ///
  /// In pt, this message translates to:
  /// **'Descrição (PT)'**
  String get adminDescPt;

  /// No description provided for @adminAudioPt.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Áudio PT'**
  String get adminAudioPt;

  /// No description provided for @adminRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get adminRemove;

  /// No description provided for @adminDescEn.
  ///
  /// In pt, this message translates to:
  /// **'Descrição (EN) - Opcional'**
  String get adminDescEn;

  /// No description provided for @adminAudioEn.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Áudio EN'**
  String get adminAudioEn;

  /// No description provided for @adminLatitude.
  ///
  /// In pt, this message translates to:
  /// **'Latitude (ex: 39.82)'**
  String get adminLatitude;

  /// No description provided for @adminLongitude.
  ///
  /// In pt, this message translates to:
  /// **'Longitude (ex: -7.49)'**
  String get adminLongitude;

  /// No description provided for @adminArLink.
  ///
  /// In pt, this message translates to:
  /// **'Link Modelo 3D (.glb)'**
  String get adminArLink;

  /// No description provided for @adminArHelper.
  ///
  /// In pt, this message translates to:
  /// **'Opcional. Cola o URL direto.'**
  String get adminArHelper;

  /// No description provided for @adminCreating.
  ///
  /// In pt, this message translates to:
  /// **'A criar POI... '**
  String get adminCreating;

  /// No description provided for @adminCreateButton.
  ///
  /// In pt, this message translates to:
  /// **'CRIAR PONTO DE INTERESSE'**
  String get adminCreateButton;

  /// No description provided for @adminFillRequired.
  ///
  /// In pt, this message translates to:
  /// **'Preenche os campos obrigatórios!'**
  String get adminFillRequired;

  /// No description provided for @adminAddAtLeastOnePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Adiciona pelo menos uma foto!'**
  String get adminAddAtLeastOnePhoto;

  /// No description provided for @adminSuccessCreated.
  ///
  /// In pt, this message translates to:
  /// **'✅ POI Criado com sucesso!'**
  String get adminSuccessCreated;

  /// No description provided for @adminErrorSaving.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gravar: {error}'**
  String adminErrorSaving(String error);

  /// No description provided for @routeMinLocations.
  ///
  /// In pt, this message translates to:
  /// **'Adiciona pelo menos 2 locais para criar um roteiro.'**
  String get routeMinLocations;

  /// No description provided for @routeTitleRequired.
  ///
  /// In pt, this message translates to:
  /// **'Dá um título ao teu roteiro!'**
  String get routeTitleRequired;

  /// No description provided for @routeInternetRequired.
  ///
  /// In pt, this message translates to:
  /// **'Precisas de internet para criar um roteiro, para que a app possa calcular a rota entre os pontos!'**
  String get routeInternetRequired;

  /// No description provided for @editRoteiroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar Roteiro'**
  String get editRoteiroTitle;

  /// No description provided for @createRoteiroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criar Novo Roteiro'**
  String get createRoteiroTitle;

  /// No description provided for @itineraryNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Nome do roteiro'**
  String get itineraryNameHint;

  /// No description provided for @addCoverPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Capa'**
  String get addCoverPhoto;

  /// No description provided for @noLocationsAddedYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não adicionaste nenhum local.'**
  String get noLocationsAddedYet;

  /// No description provided for @canAddPoisLater.
  ///
  /// In pt, this message translates to:
  /// **'Podes sempre adicionar POIs\nfuturamente ao editar um Roteiro'**
  String get canAddPoisLater;

  /// No description provided for @nearbyPois.
  ///
  /// In pt, this message translates to:
  /// **'Pontos de interesse próximos'**
  String get nearbyPois;

  /// No description provided for @noLocationsAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local disponível.'**
  String get noLocationsAvailable;

  /// No description provided for @createRoteiroButton.
  ///
  /// In pt, this message translates to:
  /// **'Criar Roteiro'**
  String get createRoteiroButton;

  /// No description provided for @saveRoteiroButton.
  ///
  /// In pt, this message translates to:
  /// **'Guardar Roteiro'**
  String get saveRoteiroButton;

  /// No description provided for @fieldRequired.
  ///
  /// In pt, this message translates to:
  /// **'Campo obrigatório'**
  String get fieldRequired;

  /// No description provided for @welcomeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo!'**
  String get welcomeTitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criar Conta'**
  String get createAccountTitle;

  /// No description provided for @emailInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Email inválido'**
  String get emailInvalid;

  /// No description provided for @minPasswordLength.
  ///
  /// In pt, this message translates to:
  /// **'Mín. 6 carateres'**
  String get minPasswordLength;

  /// No description provided for @loginButton.
  ///
  /// In pt, this message translates to:
  /// **'ENTRAR'**
  String get loginButton;

  /// No description provided for @signUpButton.
  ///
  /// In pt, this message translates to:
  /// **'CRIAR CONTA'**
  String get signUpButton;

  /// No description provided for @dontHaveAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não tens conta?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In pt, this message translates to:
  /// **'Já tens conta?'**
  String get alreadyHaveAccount;

  /// No description provided for @registerNow.
  ///
  /// In pt, this message translates to:
  /// **'Regista-te'**
  String get registerNow;

  /// No description provided for @loginHere.
  ///
  /// In pt, this message translates to:
  /// **'Entra aqui'**
  String get loginHere;

  /// No description provided for @invalidCredentialError.
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou palavra-passe incorretos.'**
  String get invalidCredentialError;

  /// No description provided for @emailAlreadyInUseError.
  ///
  /// In pt, this message translates to:
  /// **'Este e-mail já está associado a uma conta.'**
  String get emailAlreadyInUseError;

  /// No description provided for @weakPasswordError.
  ///
  /// In pt, this message translates to:
  /// **'A palavra-passe é demasiado fraca. Usa pelo menos 6 caracteres.'**
  String get weakPasswordError;

  /// No description provided for @userNotFoundError.
  ///
  /// In pt, this message translates to:
  /// **'Não existe nenhuma conta com este e-mail.'**
  String get userNotFoundError;

  /// No description provided for @networkRequestFailed.
  ///
  /// In pt, this message translates to:
  /// **'Erro de ligação à internet. Verifica a tua rede.'**
  String get networkRequestFailed;

  /// No description provided for @tooManyRequestsError.
  ///
  /// In pt, this message translates to:
  /// **'Demasiadas tentativas. Tenta novamente mais tarde.'**
  String get tooManyRequestsError;

  /// No description provided for @userDisabledError.
  ///
  /// In pt, this message translates to:
  /// **'Esta conta foi desativada. Contacta o suporte.'**
  String get userDisabledError;

  /// No description provided for @operationNotAllowedError.
  ///
  /// In pt, this message translates to:
  /// **'Operação não permitida. Contacta o suporte.'**
  String get operationNotAllowedError;

  /// No description provided for @genericAuthError.
  ///
  /// In pt, this message translates to:
  /// **'Ocorreu um erro. Tenta novamente.'**
  String get genericAuthError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
