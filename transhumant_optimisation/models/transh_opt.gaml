/* Insert your model definition here */

/**
* Name: transhopt
* Based on the internal empty template. 
* Author: Cheick Amed Diloma Gabriel TRAORE
* Tags: 
* Hypothèse de modèlisation
* Le troupeau ne peut pas consommer plus d'un tier de la biomasse d'une cellule car le reste sera dégradé naturellement ou consomé par la microfaune;
* Lorsque le pasteur n'est pas dans la zone d'influence de son réseau social, le coût de l'eau est doublé
* Le cout de vente des animaux est proportionnel à la distance du parcours du troupeau par rapport au marché. Plus il est proche du marché plus le prix est avantagieux
* 1/3 de la végétation est disponible pour le troupeau
*/
model transhopt

global {
	file shape_file_forage <- file("../includes/forage_carre.shp");
	file shape_file_appetence <- file("../includes/morpho_pedo_carre.shp");
	file shape_file_hydro_line <- file("../includes/hydro_ligne_carre.shp");
	file shape_file_zone <- file("../includes/zonage_transhumance.shp");
	file shape_file_infrastructure_pasto <- file("../includes/infrast_pasto.shp");
	geometry shape <- envelope(shape_file_appetence);

	//---------------------------------------les paramètres----------------------------------------
	date starting_date <- date([2020, 10, 15, 7, 0]);
	float step <- 1 #days;
	int nb_trp <- 20 min: 2 parameter: 'Nb_trp';
	int cpt_trp_aller;
	int cpt_trp_retour;
	int moy_cycle_aller <- 0;
	float std_cycle_aller_micro <- 0.0;
	int nb_cycle_aller;
	int nb_cycle_aller_retour;
	int nb_cycle_retour;
	bool is_batch <- false;
	float proba_pluie <- 0.2 min: 0.1 parameter: 'proba_pluie' category: "pluiviometrie";
	//---------------------------------------------------------------------------
	int eff_bovin_moy <- 111 min: 0 parameter: 'Bovin' category: "Effectif Ruminants";
	int eff_ovin_moy <- 257 min: 0 parameter: 'Ovin' category: "Effectif Ruminants";
	int eff_caprin_moy <- 69 min: 0 parameter: 'Caprin' category: "Effectif Ruminants";
	float acc_bovin_moy <- 2.5 min: -10.0 max: 10.0 parameter: 'Bovin' category: "Accroissement (%) Ruminants";
	float acc_ovin_moy <- 3.5 min: -10.0 max: 25.0 parameter: 'Ovin' category: "Accroissement (%) Ruminants";
	float acc_caprin_moy <- 4.5 min: -10.0 max: 35.0 parameter: 'Caprin' category: "Accroissement (%) Ruminants";
	float com_bovin_moy <- 4.5 min: 1.0 parameter: 'Bovin' category: "Consommation journalière biomasse";
	float com_ovin_moy <- 1.5 min: 1.0 parameter: 'Ovin' category: "Consommation journalière biomasse";
	float com_caprin_moy <- 1.5 min: 1.0 parameter: 'Caprin' category: "Consommation journalière biomasse";
	float s_cons_jour <- 0.0;
	//veterinaire
	int jour_veto <- 4 min: 0 parameter: 'jour(s)' category: 'Veterinaire';
	//float dist_veto <- 30.0 #km min: 0.0 parameter: 'dis_veto(m)' category: 'Veterinaire';
	//Réseau social
	//int jour_res_soc <- 4 min: 0 parameter: 'Nb jour' category: 'Reseau_social';
	//float p_res_social <- 0.43 min: 0.0 parameter: 'accueil_ZA' category: 'Reseau_social';

	//---------------------------------- espace et vegetation ----------------
	float largeur_cellule <- 2 #km;
	float hauteur_cellule <- 2 #km;
	float impt_trp_veg <- 0.0;
	rgb impt_trp_veg_color <- #black;
	float r_g <- 0.0;
	float r_min <- 10 ^ 50;
	float q_seuil_r <- 25.0 min: 0.0 max: 100.0 parameter: "Sueil_biomasse" category: "Impact troupeau-végétation"; //le seuil de végétation, ce sueil(25%) est tiré de Dia et Duponnois:désertification
	float qt_pluie <- 500.0 min: 105.0 parameter: 'Pluviométrie'; //rnd(100.0, 550.0) min: 50.0 max: 550.0 parameter: "Pluie(mm)" category: "Climat";
	string plvt;
	//interaction trp_veg
	float d_rech <- 40 #km min: 5 #km; // parameter: "dist-recherche-bio" category: "Impact troupeau-végétation";
	//------------------------------- paramètre d'optimisation ---------------
	int cout_eau <- 3250 parameter: "Eau" category: "Mecanisme optimisation"; // Ancey 2008
	float cou_soin_moy <- 89000.0 parameter: 'Soin' category: "Mecanisme optimisation";
	float cou_vente_moy <- 50000.0 parameter: 'vente' category: "Mecanisme optimisation";
	float cou_vol_moy <- 10000.0 parameter: 'Vol' category: "Mecanisme optimisation";
	//----------------- le calendrier pastoral ------------------------------
	date date_mj_pluie <- date([2021, 10, 10]);
	date date_mj_biomasse <- date([2021, 10, 1]);
	date d_cetcelde <- date([2021, 5, 15]);
	date f_cetcelde <- date([2021, 6, 30]);
	date fin_sai_pluie <- date([2021, 9, 30]);
	date fin_transh_au_plus_tard <- date([2021, 7, 1]);
	//------------------------- diffusion --------
	init {
		create forage from: shape_file_forage with: [forage_debit::float(get("Débit_expl"))];
		create vegetation from: shape_file_appetence with: [pasto::string(get("PASTORAL"))] {
			if pasto = "N" {
				color_vegetation <- #red; // rgb(165, 38, 10); //
			} else if pasto = "P1" {
				color_vegetation <- #darkgreen; //rgb(58, 137, 35); // pâturage généralement de bonne qualité
			} else if pasto = "P2" {
				color_vegetation <- #green; //rgb(1, 215, 88); // pâturage généralement de qualité moyenne
			} else if pasto = "P3" {
				color_vegetation <- #lime; //rgb(34, 120, 15); // pâturage généralement de qualité médiocre ou faible
			} else if pasto = "P4" {
				color_vegetation <- #aqua; // rgb(176, 242, 182); // pâturage uniquement exploitable en saison sèche, inondable
			} else {
				color_vegetation <- #grey;
			} }

		ask vegetation {
		// prise de couleur par la grille
			ask espace overlapping (self) {
				self.color <- myself.color_vegetation;
				self.e_pasto <- myself.pasto;
				if
				polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}])
				overlaps (self) {
					self.en_zone_orig <- true;
				}

				if
				polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])
				overlaps (self) {
					self.en_zone_accueil <- true;
				}

			}

		}

		create bandi_contrainte number: 20 {
			status <- flip(0.6) ? 'voleur' : 'antagoniste';
		}

		create hydro_ligne from: shape_file_hydro_line;
		create zone from: shape_file_zone;
		create infrast_pasto from: shape_file_infrastructure_pasto with: [type:: string(get("type"))];
		create troupeau number: nb_trp;
		//initialisation de plvt
		if 450.0 <= qt_pluie and qt_pluie <= 550 {
			plvt <- 'bonne';
		} else if 300.0 <= qt_pluie and qt_pluie <= 449 {
			plvt <- 'moyenne';
		} else {
			plvt <- 'sécheresse';
		} } // fin de l'init


	//----------------- debut operation de diffusion -----------
	bool diff_eau <- true;

	reflex var_dif_eau when: diff_eau {
		ask espace {
			ask forage inside self {
				myself.esp_forage <- true;
			}

			ask infrast_pasto inside self {
				if self.type = "marche" {
					myself.esp_infrast_marche <- true;
				} else {
					myself.esp_infrast_veto <- true;
				}

			}

		}

		diff_eau <- false;
	}

	reflex valeurs_influences {
		ask espace where (each.esp_infrast_marche = true) {
			influence_infras_marche <- 1.1;
		}

		/*ask espace where (each.esp_infrast_veto = true) {
			influence_infras_veto <- 0.75;
		}*/
		ask espace where (each.esp_forage = true) {
			influence_eau <- 2.5;
		}

	}

	reflex diffusions {
		diffuse var: influence_infras_marche on: espace where (each.esp_infrast_marche = true) propagation: diffusion radius: 2;
		//diffuse var: influence_infras_veto on: espace where (each.esp_infrast_veto = true) propagation: gradient; // radius: 4 #km;// valeur de ref pour déterminer celle des autres
		diffuse var: influence_eau on: espace where (each.esp_forage = true) propagation: diffusion radius: 7;
	}

	//------------- remontée FIT -------------------------------------------------------------------------------------------------
	reflex remonte_fit when: d_cetcelde <= current_date and current_date <= f_cetcelde {
		ask troupeau {
			if self.fin_transhumance = false {
				ask espace overlapping (self.location) {
					if s_pluie != 0 { // retour en fonction du FIT
						myself.fin_transhumance <- true;
						myself.en_zone_acc <- false;
						myself.date_dep <- myself.date_dep add_days 365; //write myself.date_dep;

					}

				}

			}

		}

	}

	//--------------------------------------------------------------
	reflex trp_veg when: every(step) {
		s_cons_jour <- s_cons_jour + sum(troupeau collect (each.cons_jour));
		r_g <- sum(espace collect (each.r));
		//write r_g;
		if r_g <= r_min {
			r_min <- r_g;
		}

		impt_trp_veg <- with_precision((1 - r_min / sum(espace collect (each.r_init))) * 100, 10);
	}

	//---------------------------- durée de la transhumance --------------------------------
	reflex update_comptage_trp {
		cpt_trp_aller <- sum(troupeau collect (each.presence_ter_acc));
		cpt_trp_retour <- sum(troupeau collect (each.presence_terr_orig));
	}

	reflex trp_dure_orig_acc when: cpt_trp_aller = nb_trp and is_batch { //
		nb_cycle_aller <- round((current_date - starting_date) / 86400);
		//durée approximative de la phase aller de la transhumance
		moy_cycle_aller <- round(mean(troupeau collect (each.cycle_aller_micro)));
		std_cycle_aller_micro <- standard_deviation(troupeau collect (each.cycle_aller_micro));
		//write moy_cycle_aller;
		//do pause;
	}

	reflex remplissage_grille {
		ask espace {
			if length(troupeau inside (self)) != 0 {
				s_nb_trp_inside <- s_nb_trp_inside + length(troupeau inside (self));
			}

		}

	} } // fin du global
//*************************************************************
grid espace cell_width: largeur_cellule cell_height: hauteur_cellule neighbors: 8 {
	string e_pasto;
	bool en_zone_orig <- false;
	bool en_zone_accueil <- false;
	float r; // quantité de végétation en fonction de l'équation de Boudhet 
	float r_init;
	float seuil_r;
	float influence_infras_marche <- 0.0;
	bool esp_infrast_marche <- false;
	//float influence_infras_veto <- 0.0;
	bool esp_infrast_veto <- false;
	float influence_eau <- 0.0;
	bool esp_forage <- false;
	//--------------------- carte de densité ------------------
	int s_nb_trp_inside;
	bool enregistrement <- true;
	bool enregistrement1 <- true;
	bool enregistrement2 <- true;
	int dens_seuil <- 0;
	//--------------------------------pluie ---------------------------------
	float pluie_fit;
	float s_pluie <- 0.0;
	//------------------------ fonction doptimisation -----------------------
	bool test_bol;
	int alpha1 <- 100;
	int alpha2 <- 100;
	float alpha3;
	int beta3;
	int alpha4;
	float alpha5 <- 0.0;
	int cout_eau_cell <- cout_eau;
	float cou_completion <- 150.0;
	float cou_soin <- gauss(cou_soin_moy, 10000);
	float cou_vente <- gauss(cou_vente_moy, 5000);
	float cou_vol <- gauss(cou_vol_moy, 1000);

	init {
		test_bol <- true;
		r <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1;
		r_init <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1;
		seuil_r <- 2 / 3 * r; //1-0.33333 représente le seuil de végétation pâturable dans une cellule par un troupeau
		s_nb_trp_inside <- 0;
		//---------------------- qualité du fourrage ----------------------
		if e_pasto = "P1" or "P2" {
			beta3 <- -100;
		} else if e_pasto = "P3" {
			beta3 <- 1;
		} else {
			beta3 <- 100;
		}

	}
	//-------------------------- processus d'optimisation -----------------------
	reflex var_optimisation_val_fixe when: test_bol {
	//dans ce reflex on fixe la valeur de certains indicateurs de présence de points d'eau ou d'infrastructure pastorale 
	//------ presence veterinaire
		if esp_infrast_veto {
			self.alpha4 <- -100;
			self.cou_soin <- cou_soin * 2; //si la cellule contient un véto le cout des soins est divisé par 2, cela permet une bonne minimisation car alpha4<0
		} else {
			self.alpha4 <- 0;
		}

		ask hydro_ligne overlapping (self) {
			myself.alpha1 <- 1;
			//write myself.alpha1;
		}

		ask forage overlapping (self) {
			myself.cout_eau_cell <- cout_eau;
			if myself.alpha1 = 1 {
				myself.alpha2 <- 0;
			} else {
				myself.alpha2 <- 1;
			}

		}
		//si la cellule est dans la zone d'influence d'un marché alors le prix de vente de l'animal est meilleur
		self.cou_vente <- cou_vente + self.influence_infras_marche * cou_vente;
		test_bol <- false;
	}

	reflex mj_var_optimisation when: every(#day) {
	//---------------- quantité du fourrage ------------------------
		if r >= seuil_r {
			alpha3 <- 1.0;
		} else {
			alpha3 <- seuil_r / r;
			dens_seuil <- 1; // densite du seuil
		}

	}

	//-----------------------------------------------------------------------
	reflex fit when: d_cetcelde <= current_date and current_date <= fin_sai_pluie {
		if flip(0.01) {
			pluie_fit <- rnd(2.0, 20.0);
			s_pluie <- s_pluie + pluie_fit;
			r <- r + abs(4.1 * pluie_fit - 515) * 5 * 5; //premiere_pluie <- true;
		}

	}

	//------------------------------- carte de densité -----------------
	reflex densite_aller when: cpt_trp_aller >= nb_trp and enregistrement {
	//save [grid_x, grid_y, s_nb_trp_inside] to: 'trans_opt_aller_200r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement <- false;
	}

	reflex densite_za when: cpt_trp_aller >= nb_trp and enregistrement1 and current_date > date([2021, 6, 15]) {
	//save [grid_x, grid_y, s_nb_trp_inside] to: 'trans_opt_za_200r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement1 <- false;
	}

	reflex densite_retour when: cpt_trp_retour >= nb_trp - 1 and enregistrement2 {
	//	save [grid_x, grid_y, s_nb_trp_inside] to: 'trans_opt_retour_200r.csv' rewrite: false type: 'csv';
	//save [grid_x, grid_y, dens_seuil] to: 'trans_opt_densite_200r.csv' rewrite: false type: 'csv';
		enregistrement2 <- !enregistrement2;
	}

}
//*************************************************************
species troupeau skills: [moving] {
	float step <- 1 #days;
	int eff_bovin <- poisson(eff_bovin_moy);
	float acc_bovin <- gauss(acc_bovin_moy, 0.1);
	int eff_ovin <- poisson(eff_ovin_moy);
	float acc_ovin <- gauss(acc_ovin_moy, 0.1);
	int eff_caprin <- poisson(eff_caprin_moy);
	float acc_caprin <- gauss(acc_caprin_moy, 0.1);
	float com_bovin <- com_bovin_moy;
	float com_ovin <- com_ovin_moy;
	float com_caprin <- com_caprin_moy;
	float cons_jour <- 0.0;
	int presence_ter_acc <- 0;
	int presence_terr_orig <- 0;
	int j1 <- rnd(15, 30);
	int j2 <- rnd(1, 15);
	date date_dep <- flip(0.5) ? date([2020, 10, j1, rnd(7, 8), 0]) : date([2020, 11, j2, rnd(7, 8), 0]);
	point
	terr_orig <- any_location_in(polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}])).location;
	point
	terr_acc <- any_location_in(polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])).location;
	float speed <- gauss(17.5, 2) #km / #days; //Memento agronome p.1447-1449
	image_file trp_noir <- image_file("../includes/trp_black.png");
	image_file trp_rouge <- image_file("../includes/trp_red.png");
	string objectif <- 'deplacement';
	point the_target;
	bool en_zone_acc <- false;
	bool fin_transhumance <- false;
	//-------------------- vétérinaire --------------------
	bool soin <- flip(0.7) ? true : false; // source Thebaud p.16
	int jour_veto_trp <- rnd(jour_veto);
	int k1 <- 0; //cpt le nb de jour chez le veterinaire
	//--------------------- reseau social ------------------
	int k2 <- 0; // cpt le nb de jour chez l'élément de reseau social
	int i <- 0; // vu que la diffusion ne seffectue pas d'un trait, ce compteur permet de
	point pos_elmt_soc; //la position de l'élement de reseau social ou le troupeau est allé
	list<point> res_visited <- [{0, 0, 0}];

	//------------------- optimisation---------------
	int beta4;
	float alpha5;
	int a <- 1;

	//----------------------------déplacement--------------------------------
	bool bool_cycle_aller <- true;
	int cycle_aller_micro <- 0;
	//----------------------- liaison de la topologie du trp et de la grille --
	espace my_cell <- one_of(espace inside
	polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}]));
	bool signal <- false;

	init {
		location <- my_cell.location;
		cpt_trp_aller <- 0;
		cpt_trp_retour <- 0;
	}

	reflex evolution_de_la_diffusion when: i <= 3 {
		i <- i + 1;
	}

	reflex creation_rs_1 when: i > 0 and i < 2 {
		if soin = false {
			beta4 <- 1;
		} else {
			beta4 <- 0;
		}

	}

	reflex consommation_jour {
		cons_jour <- (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
	}

	//---------------- Les effectifs d'animaux -----------------------
	reflex dynamique_population when: every(3 #month) {
		eff_bovin <- round(eff_bovin + (acc_bovin / 400) * eff_bovin);
		eff_ovin <- round(eff_ovin + (acc_ovin / 400) * eff_ovin);
		eff_caprin <- round(eff_caprin + (acc_caprin / 400) * eff_caprin);
	}
	//----------------- trp broutte -------------
	reflex trp_broutte {
		my_cell.r <- my_cell.r - cons_jour;
		if my_cell.r <= my_cell.seuil_r {
		//le transhumant estime qu'il doit se déplacer lors qu'il n'y a plus assez de pâturage 
		//on peut changer cette condition en supposant que le transhumance va déplacer son troupeau sil ny a plus assez de pâturage pour trois jours par exemple 
			self.signal <- true;
			self.alpha5 <- self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin;
			my_cell.color <- #orange;
		} else {
			self.signal <- false;
			self.alpha5 <- 0.0;
		}

	}
	//---------------------- deplacement en lien avec le veterinaire ------------
	//self.location overlaps one_of(espace where (each.esp_infrast_veto))
	reflex chez_veterinaire when: location distance_to (one_of(espace where (each.esp_infrast_veto))) <= largeur_cellule and fin_transhumance = false and soin = false {
		the_target <- nil;
		k1 <- k1 + 1;
		soin <- true;
		//write k1;
		beta4 <- 0;
		if k1 > jour_veto_trp {
			objectif <- 'quitter_veterinaire';
		}

	}

	reflex quitter_veterinaire when: objectif = 'quitter_veterinaire' {
	//the_target <- terr_acc;
		if self.location.y >= position_efficiente.y {
			the_target <- terr_acc;
		} else {
			the_target <- position_efficiente;
		}

		k1 <- 0;
		objectif <- 'deplacement';
	}

	//--------------------------- deplacement lorsqu'il manque de la biomasse -------------------------
	reflex manque_bio_rs when: signal and en_zone_acc and fin_transhumance = false and objectif = 'recherche_bio' {
		ask espace where (each.r > each.seuil_r and each.color != #red and each.location distance_to (self.location) <= d_rech) {
			myself.L1 <- myself.L1 + [self.alpha1 + self.beta3 * self.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
			myself.L2 <- myself.L2 + [self.location];
		}

		if L1 != [] {
			ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
			pos_elmt_soc <- L2 at ind;
			the_target <- pos_elmt_soc;
			res_visited <- res_visited + [pos_elmt_soc];
			do goto target: the_target;
		}

		//write min(L1);
		objectif <- 'aller_manque_bio';
		L1 <- [];
		L2 <- [];
	}

	reflex quitter_manque_bio when: objectif = 'aller_manque_bio' and self.location = pos_elmt_soc and signal {
		objectif <- 'recherche_bio';

		//write '1';
	}
	//-----------------------------------------------------------------------------------------------------
	reflex aller_za when: fin_transhumance = false and current_date >= date_dep {
		do goto target: the_target;
		if location = terr_acc { //and objectif != 'recherche_bio'
			the_target <- nil;
			en_zone_acc <- true;
			presence_ter_acc <- 1;
			objectif <- 'recherche_bio';
			//write '2';
			if bool_cycle_aller {
				cycle_aller_micro <- round((current_date - date_dep) / 86400);
				bool_cycle_aller <- !bool_cycle_aller;
			}

		}

	}

	reflex fin_transhumance when: current_date > f_cetcelde and current_date < fin_transh_au_plus_tard and fin_transhumance = false {
	//ce reflex me permet de mettre fin à la transhumance de tt le monde à partir d'une certaine date, ca evite le cas du nomadisme
		fin_transhumance <- true;
	}

	reflex retour_co when: fin_transhumance {
		do goto target: the_target;
		if location = terr_orig {
			presence_terr_orig <- 1;
			//nb_cycle_retour <- cycle - nb_cycle_aller;
			the_target <- nil;
		}

	}

	reflex volonte_vente when: every(1 #month) {
	//inspiré de Corniaux 2018 p.5
		if a = 0 {
			a <- 1;
		}

	}
	//------------------------- optimisation----------
	list<float> L1 <- [];
	list<point> L2 <- [];
	int ind <- 0;
	point position_efficiente <- nil;

	reflex optimisation when: every(#day) and (presence_ter_acc = 0 or fin_transhumance) {

	//---------------------------- fonction d'optimisation du choix du trajet --------------
		if fin_transhumance {
		//La phase retour de la transhumance
			ask espace where (each.location.y < self.location.y - 14.5 #km and each.location.y > self.location.y - 20 #km and each.location.y > self.terr_orig.y and each.location
			distance_to (self.location) <= 20 #km) {
			//le calcul de f se fait en fonction du troupeau le plus proche de la cellule
				if self.r - seuil_r - myself.alpha5 <= 0 {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.beta3 * self.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin + alpha5 * self.cou_completion - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				} else {
					myself.L1 <- myself.L1 + [self.alpha1 + self.beta3 * self.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				}

			}

			//write length(L1);
			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				position_efficiente <- L2 at ind;
				the_target <- position_efficiente;
			} else {
				the_target <- terr_orig;
			}

		} else {
		//La phase aller de la transhumance
			ask espace where (self.presence_ter_acc = 0 and each.location.y > self.location.y + 14.5 #km and each.location.y < self.location.y + 20 #km and each.location.y < self.terr_acc.y
			and each.location distance_to (self.location) <= 20 #km) {
			//le calcul de f se fait en fonction du troupeau le plus proche de la cellule
				if self.r - seuil_r - myself.alpha5 <= 0 {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.beta3 * self.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin + alpha5 * self.cou_completion - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				} else {
					myself.L1 <- myself.L1 + [self.alpha1 + self.beta3 * self.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				}

			}

			//write soin;
			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				position_efficiente <- L2 at ind;
				the_target <- position_efficiente;
			} else {
				the_target <- terr_acc;
			}

		}

		L1 <- [];
		L2 <- [];
		if a = 1 {
			a <- 0;
		}

	}
	//---------------------------- aspects -----------------------
	aspect asp_trp {
		if soin = false {
			draw square(4000) color: #red;
		} else {
			draw square(4000) color: #black;
		}

	}

	aspect asp_trp_icone {
		if soin = false {
			draw trp_rouge size: 12000.0;
		} else {
			draw trp_noir size: 12000.0;
		}

	}

} // fin du champ troupeau
//*************************************************************
species vegetation {
	string pasto;
	rgb color_vegetation;

	/*aspect asp_vegetation_base {
		draw shape color: color_vegetation;
	}*/
}
//*************************************************************
species infrast_pasto {
	string type;
	image_file veto <- image_file("../includes/veto_icone.png");
	image_file marche <- image_file("../includes/marche_icone.png");

	aspect infrast_pasto {
		if type = 'marche' {
			draw marche size: 10000.0;
		} else {
			draw veto size: 10000.0;
		}

	}

}
//*************************************************************
species forage {
	float forage_debit;

	aspect asp_forage {
		draw square(3000) color: #blue;
	}

}

//*************************************************************
species bandi_contrainte skills: [moving] {
	string status;

	reflex deplacement when: status = 'voleur' {
		do wander speed: 30 #km / #day;
	}

	aspect asp_bandi {
		if status = 'voleur' {
			draw triangle(6000) color: #magenta;
		} else {
			draw square(6000) color: #magenta;
		}

	}

}

species hydro_ligne {

	aspect eau_surface {
		draw shape color: #turquoise;
	}

}
//*************************************************************
species zone schedules: [] {

	aspect asp_zone {
		draw shape color: #gamaorange;
	}

}
//*************************************************************
experiment mecanism type: gui {
	output {
		monitor "Pluviométrie " value: plvt refresh: every(1 #month);
		display affichage_sig_zone type: opengl {
			species vegetation;
			grid espace triangulation: true; // lines: #lightgrey;
			species forage aspect: asp_forage refresh: false;
			species zone aspect: asp_zone transparency: 0.3 refresh: false;
			species hydro_ligne aspect: eau_surface;
			species bandi_contrainte aspect: asp_bandi;
			species infrast_pasto aspect: infrast_pasto refresh: false;
			species troupeau aspect: asp_trp;
		}

		display graphique type: java2D refresh: every(1 #week) {
			chart "Herbivore population" type: series size: {0.5, 0.5} position: {0, 0} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] color:
				[#blue, #black, #maroon];
			}

			chart "Impact of the herbivores on the vegetation" type: series size: {0.5, 0.5} position: {0.5, 0} {
				data "Impact of the herds on the vegetation" value: impt_trp_veg color: impt_trp_veg_color;
			}

		}

	}

}

//------------------------------------
/*experiment diffusion type: gui {
	output {
		display diffusion {
			grid espace triangulation: true lines: #lightgrey;
		}

	}

}*/
//*************************************************************************************************
experiment sauv_donne type: batch repeat: 200 until: cpt_trp_retour >= nb_trp {
	parameter 'Batch mode' var: is_batch <- true;
	//*************** sauvegarde du nombre de cycle moyen dans un fichier
	reflex save {
		save [round(simulations mean_of (each.nb_cycle_aller)), standard_deviation(simulations collect (each.nb_cycle_aller)), round(simulations mean_of
		(each.moy_cycle_aller)), std_cycle_aller_micro] to: "cycle_diffusion_100r.txt" type: text;
		//round(simulations mean_of (each.nb_cycle_retour)), standard_deviation(simulations collect (each.nb_cycle_retour)), round(simulations mean_of (each.nb_cycle_aller_retour)), standard_deviation(simulations collect (each.nb_cycle_aller_retour)),

	}

}
