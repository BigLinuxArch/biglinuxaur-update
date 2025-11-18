#!/usr/bin/env bash

webhooks() {
# curl -s -o /dev/null -w "%{http_code}" --request POST \
#   --form token=$TOKEN_BUILD \
#   --form ref=main \
#   --form "variables[org]=biglinuxaur" \
#   --form "variables[package_name]=$package" \
#   --form "variables[git_branch]=$branch" \
#   https://gitlabx.bigib.org/api/v4/projects/28/trigger/pipeline

curl -X POST -H "Accept: application/json" -H "Authorization: token $tokenBuild" \
  --data '{
    "event_type": "BigLinuxArch/'$pkgname'",
    "client_payload": {
      "branch": "'main'",
      "url": "'https://github.com/BigLinuxArch/$pkgname'"
      }
    }' \
    https://api.github.com/repos/BigLinuxArch/build-package/dispatches
}

sendWebHooks() {
echo -e "Enviando \033[01;31m$pkgname\033[0m para Package Build"
# echo -e "Base ${cor}${base}${std}"
echo " AUR ""$pkgname"="$verAurOrg"
# echo "Repo ""$pkgname"="$verRepoOrg"
# echo "Branch $branch"
sleep 1
webhooks
}

std='\e[m'

# Limpa disable-list
sed -i 's/#.*$//' disable-list
sed -i '/^$/d' disable-list

# bases=(
# manjaro
# )
# archlinux

arch=x86_64

# # Gerar Json com os dados dos repos
# biglinuxaur_id=19
for page in {1..10}; do
  echo "Fetching page $page..."
  curl -s "https://api.github.com/users/biglinuxarch/repos?per_page=100&page=$page" | \
    jq '[.[] | {name: .name, default_branch: .default_branch}]' >> "tmp.json"
done

jq -s 'add' "tmp.json" > "biglinuxArchAur.json"
rm -f tmp.json

if [ ! -e "biglinuxArchAur.json" ];then
  echo "biglinuxArchAur.json não existe"
  echo "saindo...."
  exit 1
fi

for p in $(jq -r 'sort_by(.name)[].name' biglinuxArchAur.json); do
#   for base in ${bases[@]}; do

    pkgname=
    # declara nome do pacote
    pkgname=$p

    if [ ! -e "biglinuxArchAur.json" ];then
      echo "biglinuxArchAur.json não existe"
      echo "pulando...."
      continue
    fi
    if [ ! -e "disable-list" ];then
      echo "disable-list não existe"
      echo "pulando...."
      continue
    fi

    # Disabled List
    if [ -n "$(grep $pkgname disable-list)" ];then
      echo "$pkgname disabilitado"
      echo "pulando...."
      continue
    elif [ -n "$(grep $pkgname weekly-list)" ] && [ "$(date +%u)" != "4" ];then
      echo "$pkgname"
      echo "build só nas 5ºs, pulando...."
      continue
    fi

    # Hourly list
    if [ "$scheduled" = "hourly" ] && [ -z "$(grep $pkgname hourly-list)" ];then
      continue
    fi

    # # Define o branch
    # branch=
    # branch=$(jq --arg name "$pkgname" -r '.[] | select(.name == $name) | .default_branch' biglinuxArchAur.json)
    # if [ "$branch" = "main" -a "$base" = "manjaro" ]; then
    #   branch=$repo_unstable
    #   repo='bigiborg'
    # else
    #   repo='biglinux'
    # fi
    repo='biglinux'
    branch='archlinux'

    # Versão do repositorio BigLinux
    verrepo=
    verRepoOrg=
    veraur=
    verAurOrg=
    pkgver=
    pkgrel=
    # if [ "$base" = "manjaro" ];then
    #   verrepo=$(pacman -Sl $repo-$branch | grep " $pkgname " | awk '{print $3}' | cut -d ":" -f2)
    #   cor='\e[32;1m'
    # elif [ "$base" = "archlinux" ]; then
    #   verrepo=$(pacman -Sl $repo-$base | grep " $pkgname " | awk '{print $3}' | cut -d ":" -f2)
    #   cor='\e[34;1m'
    # fi
    verrepo=$(pacman -Sl $repo-$branch | grep " $pkgname " | awk '{print $3}' | cut -d ":" -f2)

    # if [ -n "$(grep xanmod <<< $pkgname)" ];then
    #   verRepoOrg=$verrepo
    #   #add 0 no 2º numero da versão
    #   verrepo=$(echo "$verrepo" | awk -F'.' '{ split($3, a, "-"); if (length($2) == 1) $2 = "0"$2; print $1"."$2"."a[1]"-"a[2]}')
    #   #add 0 no 3º numero da versão
    #   verrepo=$(echo "$verrepo" | awk -F'.' '{ split($3, a, "-"); if (length(a[1]) == 1) a[1] = "0"a[1]; print $1"."$2"."a[1]"-"a[2] }')
    #   #remove . e -
    #   verrepo=${verrepo//[-.]}
    # else
      verRepoOrg=$verrepo
      verrepo=${verrepo//[-.]}
    # fi

    # soma +1 ao pkgNum
    pkgNum=$((pkgNum+1))

    # Enviar caso não encontre no repo ou seja algum dos mesa-tkg
    if [ -z "$verrepo" ] || [ "$(grep mesa-tkg <<< $pkgname)" ];then
      sendWebHooks
      continue
    fi

    #versão do AUR
    #limpa todos os $
    veraur=
    verAurOrg=
    pkgver=
    pkgrel=

    # # if Linux Xanmod rename
    # if [ -n "$(grep "linux-xanmod" <<< $pkgname | grep -v "lts")" ];then
    #   pkgname=$(sed 's/linux-xanmod/linux-xanmod-linux-bin/' <<< $pkgname)
    # elif [ -n "$(grep "linux-xanmod-lts" <<< $pkgname)" ];then
    #   pkgname=$(sed 's/linux-xanmod-lts/linux-xanmod-lts-linux-bin/' <<< $pkgname)
    # fi

    # gitClone
    git clone https://aur.archlinux.org/${pkgname}.git > /dev/null 2>&1

    if [ ! -d "$pkgname" ];then
      echo "diretorio $pkgname não existe"
      echo "pulando...."
      continue
    fi

    cd $pkgname
    if [ -z "$(grep 'pkgver()' PKGBUILD)" ];then
      source PKGBUILD
      veraur=$pkgver-$pkgrel
      verAurOrg=$veraur
    else
      chmod 777 -R ../$pkgname
      sudo -u builduser bash -c 'makepkg -so --noconfirm --skippgpcheck --needed > /dev/null 2>&1'
      sleep 1
      source PKGBUILD
      veraur=$pkgver-$pkgrel
      verAurOrg=$veraur
    fi

    # if [ -n "$(grep xanmod <<< $pkgname)" ];then
    #   #add 0 no 2º numero da versão
    #   veraur=$(echo "$veraur" | awk -F'.' '{ split($3, a, "-"); if (length($2) == 1) $2 = "0"$2; print $1"."$2"."a[1]"-"a[2]}')
    #   #add 0 no 3º numero da versão
    #   veraur=$(echo "$veraur" | awk -F'.' '{ split($3, a, "-"); if (length(a[1]) == 1) a[1] = "0"a[1]; print $1"."$2"."a[1]"-"a[2] }')
    #   #remove . e -
    #   veraur=${veraur//[.-]}
    # else
      veraur=${veraur//[.-]}
    # fi


    # Remove +...
    veraur=${veraur%%+*}
    verAurOrg=${verAurOrg%%+*}

    # Vririficar se source PKGBUILD alterou o $pkgname
    if [ "$pkgname" != "$p" ]; then
      pkgname=$p
    fi

    #apagar diretorio do git
    cd ..
    # if [ "$(grep "linux-xanmod" <<< $pkgname)" ];then
    #   rm -r linux-xanmod*
    # else
      rm -r $pkgname
    # fi

    # echo "..."
    # echo "pkgname=$pkgname"
    # echo "veraur=$veraur"
    # echo "verAurOrg=$verAurOrg"
    # echo "verrepo=$verrepo"
    # echo "verRepoOrg=$verRepoOrg"

    # MSG de ERRO
    if [ -z "$veraur" ];then
      echo -e '\033[01;31m!!!ERRRRRO!!!\033[0m' $pkgname não encontrado '\033[01;31m!!!ERRRRRO!!!\033[0m'
      continue
    # se contiver apenas numeros ou se for com hash
    elif [[ $veraur =~ ^[0-9]+$ ]] || [[ $verrepo =~ ^[0-9]+$ ]]; then
      if [ "$veraur" -gt "$verrepo" ]; then
        sendWebHooks
      else
        echo -e "Versão do \033[01;31m$pkgname\033[0m é igual !"
        # echo -e "Base ${cor}${base}${std}"
        # echo "Branch $branch"
        sleep 1
      fi
    else
      # Enviar hooks
      if [ "$veraur" != "$verrepo" ]; then
        sendWebHooks
      else
        echo -e "Versão do \033[01;31m$pkgname\033[0m é igual !"
        echo -e "Base ${cor}${base}${std}"
        # echo "Branch $branch"
        sleep 1
      fi
    fi
#   done
  echo '---'
done

# Print numero final de pacotes
echo "pkgNum=$pkgNum"


