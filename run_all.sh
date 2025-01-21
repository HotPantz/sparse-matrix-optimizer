#!/bin/bash

# run_all.sh
# Script pour compiler et profiler la Multiplication Matrice-Vecteur Sparse (SPMXV) en utilisant les compilateurs GCC et OneAPI ICPX.

# Quitter immédiatement si une commande échoue
set -e

# Répertoires
RESULTS_DIR="results"
UTILS_DIR="utils"

# Créer le répertoire des résultats s'il n'existe pas
mkdir -p "${RESULTS_DIR}"

# Détecter le nombre maximum de cœurs physiques
MAX_PHYSICAL_CORES=$(lscpu | awk '/^Core\(s\) per socket:/ {cores_per_socket=$4} /^Socket\(s\):/ {print cores_per_socket * $2}')
echo "Nombre maximum de cœurs physiques détectés : ${MAX_PHYSICAL_CORES}"

# Définir les nombres de cœurs à tester selon le nombre maximum de cœurs physiques
declare -a CORE_TESTS=()

case "${MAX_PHYSICAL_CORES}" in
    2)
        CORE_TESTS=(1 2)
        ;;
    4)
        CORE_TESTS=(1 2 3 4)
        ;;
    6)
        CORE_TESTS=(1 2 3 4 6)
        ;;
    8)
        CORE_TESTS=(1 2 4 8)
        ;;
    16)
        CORE_TESTS=(1 2 4 8 16)
        ;;
    *)
        echo "Nombre de cœurs physiques non supporté pour les tests de scalabilité."
        exit 1
        ;;
esac

# Fonctions de compilation
compile_code() {
    local compiler=$1
    local optimization=$2
    local output_exe="spmxv_${compiler}_${optimization}.exe"

    echo "Compilation avec ${compiler} ${optimization}..."

    if [ "${compiler}" == "g++" ]; then
        ${compiler} -fno-omit-frame-pointer ${optimization} -I "${UTILS_DIR}" -o "${RESULTS_DIR}/${output_exe}" main.cpp "${UTILS_DIR}"/*.cpp -fopenmp
    elif [ "${compiler}" == "icpx" ]; then
        ${compiler} -fno-omit-frame-pointer ${optimization} -I "${UTILS_DIR}" -o "${RESULTS_DIR}/${output_exe}" main.cpp "${UTILS_DIR}"/*.cpp -qopenmp
    else
        echo "Compilateur non supporté : ${compiler}"
        return 1
    fi

    echo "Compilation réussie : ${output_exe}"
}

# Fonction de profilage avec MAQAO
profile_code() {
    local exe_path=$1
    local profiler_result=$2
    local maqao_mode=$3
    local cores=$4

    echo "Profilage de ${exe_path} avec MAQAO en mode ${maqao_mode} sur ${cores} cœur(s)..."

    # Exécuter MAQAO avec le mode spécifié
    case "${maqao_mode}" in
        stability)
            MAQAO_RUN_OPTIONS="--mode stability"
            ;;
        standard)
            MAQAO_RUN_OPTIONS="--mode standard"
            ;;
        scalability)
            MAQAO_RUN_OPTIONS="--mode scalability"
            ;;
        *)
            echo "Mode MAQAO non supporté : ${maqao_mode}"
            return 1
            ;;
    esac

    # Définir le nombre de threads OpenMP
    export OMP_NUM_THREADS=${cores}

    # Exécuter MAQAO et rediriger la sortie
    maqao ${MAQAO_RUN_OPTIONS} "${exe_path}" > "${profiler_result}" 2>&1

    echo "Profilage terminé : ${profiler_result}"
}

# Fonction pour exécuter toutes les mesures
run_all() {
    # Compilateurs et flags d'optimisation
    declare -a compilers=("g++" "icpx")
    declare -a optimizations=("-O3" "-Ofast")

    for compiler in "${compilers[@]}"; do
        for optimization in "${optimizations[@]}"; do
            # Compiler le code
            compile_code "${compiler}" "${optimization}"

            # Définir le chemin de l'exécutable
            exe_path="${RESULTS_DIR}/spmxv_${compiler}_${optimization}.exe"

            # Vérifier si l'exécutable existe
            if [ ! -f "${exe_path}" ]; then
                echo "Exécutable introuvable : ${exe_path}"
                continue
            fi

            # *** Mesure de stabilité ***
            stability_result="${RESULTS_DIR}/spmxv_${compiler}_${optimization}_stability_cores${MAX_PHYSICAL_CORES}_maqao.log"
            profile_code "${exe_path}" "${stability_result}" "stability" "${MAX_PHYSICAL_CORES}"

            # *** Mesure standard ***
            standard_result="${RESULTS_DIR}/spmxv_${compiler}_${optimization}_standard_cores${MAX_PHYSICAL_CORES}_maqao.log"
            profile_code "${exe_path}" "${standard_result}" "standard" "${MAX_PHYSICAL_CORES}"

            # *** Mesures d’extensibilité (scalabilité) ***
            for cores in "${CORE_TESTS[@]}"; do
                scalability_result="${RESULTS_DIR}/spmxv_${compiler}_${optimization}_scalability_cores${cores}_maqao.log"
                profile_code "${exe_path}" "${scalability_result}" "scalability" "${cores}"
            done

            echo "-------------------------------------------"
        done
    done

    echo "Toutes les compilations et les profilages MAQAO sont terminés. Vérifiez le dossier '${RESULTS_DIR}' pour les résultats."
}

# Vérifier si MAQAO est installé
if ! command -v maqao &> /dev/null; then
    echo "MAQAO n'a pas été trouvé. Veuillez installer MAQAO et vous assurer qu'il est dans votre PATH."
    exit 1
fi

# Vérifier si g++ est installé
if ! command -v g++ &> /dev/null; then
    echo "g++ n'a pas été trouvé. Veuillez installer g++ et vous assurer qu'il est dans votre PATH."
    exit 1
fi

# Vérifier si icpx est installé
if ! command -v icpx &> /dev/null; then
    echo "icpx n'a pas été trouvé. Veuillez installer Intel OneAPI ICPX et vous assurer qu'il est dans votre PATH."
    exit 1
fi

# Exécuter le processus complet
run_all