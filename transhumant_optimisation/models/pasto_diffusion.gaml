/**
* Name: pasto
* Based on the internal empty template. 
* Author: Cheick Amed Diloma Gabriel TRAORE
* Tags: 
*/
model pasto

/* Insert your model definition here 
 * 
 * ---------------------------
 * Hypothèses de modélisation
 * Il ne manque pas de végétation pendant les déplacements en phase aller et retour de la transhumance;
 * il y a toujour de l'eau au niveau d'un point d'eau (ces points d'eau ne sont pas temporaires);
 * la transhumance des troupeaux s'achève au plus tard le 1 juillet car tous les troupeauc doivent rentrer chez dans leur terroir d'origine;
 * */
global {
	file shape_file_forage <- file("../includes/forage_carre.shp");
	file shape_file_appetence <- file("../includes/morpho_pedo_carre.shp");
	//file shape_file_hydro_line <- file("../includes/hydro_ligne_carre.shp");
	file shape_file_zone <- file("../includes/zonage_transhumance.shp");
	file shape_file_infrastructure_pasto <- file("../includes/parc_a_vaccination_sen_coupe.shp");
	geometry shape <- envelope(shape_file_appetence);

	//---------------------------------------les paramètres----------------------------------------
	date starting_date <- date([2020, 10, 15, 7, 0]);
	float step <- 1 #days;
	int nb_trp <- 200 min: 2 parameter: 'Nb_trp';
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
	int jour_veto <- 2 min: 0 parameter: 'jour(s)' category: 'Veterinaire';
	float dist_veto <- 30.0 #km min: 0.0 parameter: 'dis_veto(m)' category: 'Veterinaire';
	//Réseau social
	int nb_elmt_s <- 10 min: 0 parameter: 'Nb element' category: 'Reseau_social';
	int jour_res_soc <- 2 min: 0 parameter: 'Nb jour' category: 'Reseau_social';
	float p_res_social <- 0.43 min: 0.0 parameter: 'accueil_ZA' category: 'Reseau_social';

	//---------------------------------- espace et vegetation ----------------
	float largeur_cellule <- 5 #km;
	float hauteur_cellule <- 5 #km;
	float impt_trp_veg <- 0.0;
	rgb impt_trp_veg_color <- #black;
	float r_g <- 0.0;
	float r_min <- 10 ^ 50;
	float q_seuil_r <- 25.0 min: 0.0 max: 100.0 parameter: "Sueil_biomasse" category: "Impact troupeau-végétation"; //le seuil de végétation, ce sueil(25%) est tiré de Dia et Duponnois:désertification
	float qt_pluie <- 500.0 min: 105.0 parameter: 'Pluviométrie'; //rnd(100.0, 550.0) min: 50.0 max: 550.0 parameter: "Pluie(mm)" category: "Climat";
	string plvt;
	//interaction trp_veg
	float d_rech <- 20 #km min: 10 #km; // parameter: "dist-recherche-bio" category: "Impact troupeau-végétation";
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

		ask vegetation { //where (each.color_vegetation = #red)
		// prise de couleur par la grille
			ask espace overlapping (self) {
				self.color <- myself.color_vegetation;
				self.e_pasto <- myself.pasto;
				if
				polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}])
				overlaps (self) {
					self.en_zone_orig <- true;
				}

			}

		}

		/*create bandi_contrainte number: 20 {
			status <- flip(0.6) ? 'voleur' : 'antagoniste';
		}*/
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

	//---------------------------------------------------- couleur de l'espace --------------------------------		
	/*reflex update_color when: every(step) and current_date > date([2020, 10, 20, 7, 0]) {
		ask espace {
			if e_pasto = "N" and r > seuil_r {
				color <- #red;
			} else if e_pasto = "P1" and r > seuil_r {
				color <- rgb(rgb(58, 137, 35), r / r_init);
			} else if e_pasto = "P2" and r > seuil_r {
				color <- rgb(rgb(1, 215, 88), r / r_init);
			} else if e_pasto = "P3" and r > seuil_r {
				color <- rgb(rgb(34, 120, 15), r / r_init);
			} else if e_pasto = "P4" and r > seuil_r {
				color <- rgb(rgb(176, 242, 182), r / r_init);
			} else {
				if r <= seuil_r {
					color <- #orange;
				} else {
					color <- #white;
				}

			} } }*/

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
		ask espace where (each.esp_infrast_marche = true) {
			influence_infras_marche <- 1.6; // peut importe la valeur, on sen fiche, pourvu que ça varie en bas
		}

		ask espace where (each.esp_infrast_veto = true) {
			influence_infras_veto <- 1.6;
		}

		ask espace where (each.esp_forage = true) {
			influence_eau <- 1.6;
		}

	}

	bool diffusion1 <- false;

	reflex diffusions when: diff_eau = false and cycle < 2 {
	//diffuse var: influence_infras_marche on: espace where (each.esp_infrast_marche = true) propagation: diffusion radius: int(9 #km / largeur_cellule);
		diffuse var: influence_infras_veto on: espace where (each.esp_infrast_veto = true) propagation: diffusion radius: int(4 #km / largeur_cellule); // valeur de ref pour déterminer celle des autres
		diffuse var: influence_eau on: espace where (each.esp_forage = true) propagation: diffusion radius: int(15 #km / largeur_cellule);
		diffusion1 <- true;
		ask espace {
			color <- hsb(0, 1, influence_eau);
		}

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
						//write 'fin transhumance ' + self.name;
					}

				}

			}

		}

	}

	//---------------------------------- veterinaire --------------------------------
	reflex position_veto {
	//if length(infrast_pasto where (each.type = 'veto')) != 0 {
		ask espace where (each.influence_infras_veto != 0) {
			ask troupeau where (each.soin = false) {
				if self distance_to myself <= dist_veto {
					self.objectif <- 'veterinaire';
					self.position_veto <- myself.location;
				}

			}

		}

		//}

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

	reflex trp_dure_orig_acc when: cpt_trp_aller >= nb_trp - 3 and cpt_trp_aller < nb_trp and is_batch {
		nb_cycle_aller <- cycle;
		//durée approximative de la phase aller de la transhumance
		moy_cycle_aller <- round(mean(troupeau collect (each.cycle_aller_micro)));
		std_cycle_aller_micro <- standard_deviation(troupeau collect (each.cycle_aller_micro)); //do pause;
	}

	reflex remplissage_grille {
		ask espace {
			if length(troupeau inside (self)) != 0 {
				s_nb_trp_inside <- s_nb_trp_inside + length(troupeau inside (self));
			}

		}

	} } // fin du global
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
	point the_target <- terr_acc;
	bool en_zone_acc <- false;
	bool fin_transhumance <- false;
	//-------------------- vétérinaire --------------------
	bool soin <- flip(0.7) ? true : false; // source Thebaud p.16
	point position_veto;
	int jour_veto_trp <- jour_veto;
	int k1 <- 0; //cpt le nb de jour chez le veterinaire
	//--------------------- reseau social ------------------
	bool res_soc_za <- flip(p_res_social);
	int k2 <- 0; // cpt le nb de jour chez l'élément de reseau social
	int i <- 0; // vu que la diffusion ne seffectue pas d'un trait, ce compteur permet de
	int nb_element_social <- nb_elmt_s;
	point pos_elmt_soc; //la position de l'élement de reseau social ou le troupeau est allé
	int jour_res_social_trp <- rnd(jour_res_soc);
	point position_social;
	list<point> res_visited <- [{0, 0, 0}];
	list<point> rs;
	bool creation <- true;
	//----------------------------déplacement--------------------------------
	bool bool_cycle_aller <- true;
	int cycle_aller_micro <- 0;
	//------------------------------------ liaison de la topologie du trp et de la grille
	espace my_cell <- one_of(espace inside
	polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}]));
	bool signal <- false;

	init {
		location <- my_cell.location;
		cpt_trp_aller <- 0;
		cpt_trp_retour <- 0;
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
	image_file marche <- image_file("../includes/stars_gold_red.png");

	aspect infrast_pasto {
		if type = 'marche' {
			draw veto size: 10000.0;
		} else {
			draw marche size: 10000.0;
		}

	}

}
//*************************************************************
species forage {
	float forage_debit;

	aspect asp_forage {
		draw triangle(3000) color: #blue;
	}

}

//*************************************************************
/*species bandi_contrainte skills: [moving] {
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

}*/
//*************************************************************
species zone schedules: [] {

	aspect asp_zone {
		draw shape color: #gamaorange;
	}

}
//*************************************************************
grid espace cell_width: largeur_cellule cell_height: hauteur_cellule neighbors: 8 {
	string e_pasto;
	bool en_zone_orig <- false;
	float r; // quantité de végétation en fonction de l'équation de Boudhet 
	float r_init;
	float seuil_r;
	float influence_infras_marche <- 0.0;
	bool esp_infrast_marche <- false;
	float influence_infras_veto <- 0.0;
	bool esp_infrast_veto <- false;
	float influence_eau <- 0.0;
	bool esp_forage <- false;
	//--------------------- carte de densité ------------------
	int s_nb_trp_inside;
	bool enregistrement <- true;
	bool enregistrement1 <- true;
	bool enregistrement2 <- true;
	//--------------------------------pluie -----------------------------------------
	float pluie_fit;
	float s_pluie <- 0.0;

	init {
		r <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1;
		r_init <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1;
		seuil_r <- 0.66 * r; //1-0.33333 représente le seuil de végétation pâturable dans une cellule par un troupeau
		s_nb_trp_inside <- 0;
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
	reflex densite_aller when: cpt_trp_aller >= nb_trp and enregistrement { // date([2021,6,18]>= current_date
	//save [grid_x, grid_y, s_nb_trp_inside] to: 'diffusion_aller_200r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement <- false;
	}

	reflex densite_za when: cpt_trp_aller >= nb_trp and enregistrement1 and current_date > date([2021, 6, 15]) { // date([2021,6,18]>= current_date
	//save [grid_x, grid_y, s_nb_trp_inside] to: 'diffusion_za_200r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement1 <- false;
	}

	reflex densite_retour when: cpt_trp_retour >= nb_trp - 1 and enregistrement2 {
	//	save [grid_x, grid_y, s_nb_trp_inside] to: 'diffusion_retour_200r.csv' rewrite: false type: 'csv';
		enregistrement2 <- !enregistrement2;
	}
	//rgb color <- hsb(influence_infras_marche, 1.0, 1.0) update: hsb(influence_infras_marche, 1.0, 1.0);
	/*reflex couleur {
		if influence_total = 0 {
			color <- #white;
		} else {
		//color <- hsb(influence_total, 1.0, 1.0);
			color <- #white;
		}

	}*/
}
//*************************************************************
experiment pasto type: gui {
	output {
		monitor "Pluviométrie " value: plvt refresh: every(1 #month);
		display affichage_sig_zone type: opengl {
		//species vegetation;
			grid espace triangulation: true; // lines: #lightgrey;
			//species zone aspect: asp_zone transparency: 0.3 refresh: false;
			species forage aspect: asp_forage refresh: false;

			//species bandi_contrainte aspect: asp_bandi;
			//species infrast_pasto aspect: infrast_pasto refresh: false;
			//species troupeau aspect: asp_trp;
		}

		display graphique type: java2D refresh: every(1 #week) {
			chart "herds size" type: series size: {0.5, 0.5} position: {0, 0} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] color:
				[#blue, #black, #maroon];
			}

			/*chart "Weekly quantity of vegetation" type: series size: {0.5, 0.5} position: {0, 0.5} {
				datalist ["Vegetation"] value: [sum(vegetation collect (each.r))] color: [#green];
				data "Herd" value: s_cons_jour color: #blue;
				//ajouter le graphique de l'impact de la micro faune
			}*/
			chart "Impact of the herd on the vegetation" type: series size: {0.5, 0.5} position: {0.5, 0} {
				data "Impact of herds on vegetation" value: impt_trp_veg color: impt_trp_veg_color;
				//ajouter le graphique de l'impact de la micro faune
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
